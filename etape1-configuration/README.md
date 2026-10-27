# Étape 1 : Préparer les autorités

## Objectif
Préparer l'arborescence de travail et les deux fichiers de configuration OpenSSL : `racine.cnf` (AC racine) et `inter.cnf` (AC intermédiaire).

## Prérequis
- Kali Linux (VM), OpenSSL 3.x (`openssl version`)
- Dépôt cloné dans `~/TP_crypto_openssl`

## Remarque sur la source des fichiers
Le sujet mentionne « les deux fichiers de configuration fournis (annexe B) ». Cette annexe ne figurait pas dans le PDF reçu. Les deux fichiers ont donc été rédigés d'après le tableau d'architecture de la section 3.2 du sujet. Ils sont à comparer avec l'annexe B si elle est obtenue.

## Fichiers
| Fichier | Rôle |
|---|---|
| `racine.cnf` | Configuration de l'AC racine : signe l'intermédiaire et sa propre CRL |
| `inter.cnf` | Configuration de l'AC intermédiaire : signe les certificats serveur et client |

Le dossier `work/` (exclu de Git par `.gitignore`) contient l'arborescence réelle des deux AC : clés privées, `index.txt`, `serial`, `crlnumber`, `newcerts/`, `crl/`.

## Commandes
Depuis `~/TP_crypto_openssl` :

    mkdir work && cd work
    mkdir -p racine/newcerts racine/crl inter/newcerts inter/crl
    touch racine/index.txt inter/index.txt
    echo 1000 > racine/serial && echo 1000 > inter/serial
    echo 1000 > racine/crlnumber && echo 1000 > inter/crlnumber
    cp ../etape1-configuration/*.cnf .

## Explication des directives

### Section d'AC (`CA_racine` / `CA_inter`)
| Directive | Rôle |
|---|---|
| `dir` | Dossier de travail de l'AC |
| `database` | `index.txt` : liste des certificats émis et révoqués |
| `new_certs_dir` | Copie de chaque certificat émis, nommée par son numéro de série |
| `serial` | Prochain numéro de série à attribuer |
| `crlnumber` | Numéro de la prochaine CRL |
| `certificate` / `private_key` | Certificat et clé privée de l'AC |
| `default_md` | Hachage de la signature : `sha384` (racine, clé P-384), `sha256` (intermédiaire, clé P-256) |
| `default_days` | Durée de validité par défaut des certificats émis |
| `default_crl_days` | Durée de validité d'une CRL (30 jours) |
| `policy` | Section qui impose les champs du sujet du certificat |
| `unique_subject = no` | Autorise plusieurs certificats avec le même sujet (renouvellements) |
| `copy_extensions = copy` | (`inter.cnf`) Recopie dans le certificat les extensions demandées dans la CSR, notamment le SAN. Ne remplace pas celles déjà fixées par la configuration |

### Politique `policy_tp`
`commonName = supplied` rend le CN obligatoire. Le pays et l'organisation sont facultatifs.

### Extensions de l'intermédiaire (`ext_inter`, dans `racine.cnf`)
| Ligne | Rôle |
|---|---|
| `basicConstraints = critical, CA:TRUE, pathlen:0` | Ce certificat est une AC, mais ne peut signer que des certificats finaux (aucune AC en dessous). `critical` : un client qui ne comprend pas l'extension doit rejeter le certificat |
| `keyUsage = critical, keyCertSign, cRLSign` | La clé ne sert qu'à signer des certificats et des CRL |
| `subjectKeyIdentifier = hash` | Identifiant de la clé publique du certificat |
| `authorityKeyIdentifier = keyid:always` | Identifiant de la clé de l'émetteur : relie le certificat à son AC dans la chaîne |
| `nameConstraints = critical, permitted;DNS:tp.local, permitted;email:tp.local` | Limite les noms que cette AC peut valablement certifier : le domaine `tp.local` (et ses sous-domaines) et les adresses email de `tp.local`. Le contrôle est fait par le client à la validation, pas par l'AC à la signature |

### Extensions des certificats finaux (`inter.cnf`)
| Ligne | Rôle |
|---|---|
| `basicConstraints = critical, CA:FALSE` | Certificat final : ne peut pas signer d'autres certificats |
| `keyUsage = critical, digitalSignature` | La clé sert à signer (suffisant pour une clé elliptique en TLS) |
| `extendedKeyUsage = serverAuth` (`ext_serveur`) | Certificat utilisable pour un serveur TLS |
| `extendedKeyUsage = clientAuth` (`ext_client`) | Certificat utilisable pour un client TLS |
| `subjectKeyIdentifier` / `authorityKeyIdentifier` | Identification de la clé du certificat et de celle de son émetteur |

## Vérifications
    grep -c '\$dir' etape1-configuration/racine.cnf etape1-configuration/inter.cnf   # 6 et 6
    diff etape1-configuration/racine.cnf work/racine.cnf                              # aucune sortie
    find work | sort                                                                  # arborescence attendue

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `$dir` remplacé par du vide dans le fichier | Guillemets oubliés autour de `'EOF'` | Recréer le fichier avec `<< 'EOF'` |
| `I am unable to access the ./racine/newcerts` | Commande lancée hors de `work/` | Se placer dans `work/` avant `openssl ca` |
| `unable to open ... index.txt` | Fichier non créé | Refaire les commandes `touch` |
