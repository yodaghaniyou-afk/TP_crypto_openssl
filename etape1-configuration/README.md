# Étape 1 : Préparer les autorités

## Objectif
Préparer l'arborescence de travail et installer les deux fichiers de configuration OpenSSL fournis en annexe B : `racine.cnf` (AC racine) et `inter.cnf` (AC intermédiaire).

## Prérequis
- Kali Linux (VM), OpenSSL 3.x (`openssl version`)
- Dépôt cloné dans `~/TP_crypto_openssl`

## Origine des fichiers
`racine.cnf` et `inter.cnf` sont ceux de l'annexe B du sujet. Ils ont été recopiés à partir du texte du PDF de l'annexe : la ligne `nameConstraints` de la racine, coupée par le retour à la ligne du PDF, est écrite sur une seule ligne.

Une première version de ces fichiers, reconstruite d'après le tableau d'architecture du sujet avant réception de l'annexe, a été remplacée. Les étapes 3 à 7 ont été refaites avec les fichiers du professeur. La racine (étape 2), qui ne dépend pas de ces fichiers, a été conservée.

## Fichiers
| Fichier | Rôle |
|---|---|
| `racine.cnf` | Configuration de l'AC racine : signe l'intermédiaire et sa propre CRL |
| `inter.cnf` | Configuration de l'AC intermédiaire : signe les certificats de serveur et de client |

Le dossier `work/` (exclu de Git par `.gitignore`) contient l'arborescence réelle des deux AC : clés privées, bases `index.txt`, `serial`, `crlnumber`, `certs/`, `crl/`, `newcerts/`.

## Commandes
Depuis `~/TP_crypto_openssl` :

    mkdir work && cd work
    mkdir -p racine/{certs,crl,newcerts} inter/{certs,crl,newcerts}
    touch racine/index.txt inter/index.txt
    echo 1000 > racine/serial && echo 1000 > racine/crlnumber
    echo 2000 > inter/serial && echo 2000 > inter/crlnumber
    cp ../etape1-configuration/*.cnf .

Les numéros de série sont en hexadécimal : `1000` correspond à 4096 en décimal.

## Explication des directives

### Section d'AC (`ca_racine` dans `racine.cnf`, `ca_inter` dans `inter.cnf`)
| Directive | Rôle |
|---|---|
| `[ ca ]` / `default_ca` | Désigne l'autorité utilisée par défaut par `openssl ca` |
| `dir` | Dossier de travail de l'AC (`$dir` renvoie à cette valeur) |
| `database` | `index.txt` : liste des certificats émis et révoqués |
| `new_certs_dir` | Copie de chaque certificat émis, nommée par son numéro de série |
| `serial` | Prochain numéro de série à attribuer |
| `crlnumber` | Numéro de la prochaine CRL |
| `certificate` / `private_key` | Certificat et clé privée de l'AC |
| `default_md` | Hachage de la signature : `sha384` pour la racine, `sha256` pour l'intermédiaire |
| `default_crl_days` | Durée de validité d'une CRL : 30 jours (racine), 7 jours (intermédiaire) |
| `policy = politique_souple` | Section qui fixe les champs du sujet exigés |
| `copy_extensions` | `none` (racine) : les extensions de la CSR sont ignorées, la racine impose les siennes. `copy` (intermédiaire) : les extensions de la CSR absentes de la configuration sont recopiées, ce qui conserve le SAN du serveur |

### Section `politique_souple`
`commonName = supplied` rend le nom commun obligatoire. Le pays et l'organisation sont facultatifs.

### Extensions de l'intermédiaire (`ext_inter`, dans `racine.cnf`)
| Ligne | Rôle |
|---|---|
| `basicConstraints = critical,CA:TRUE,pathlen:0` | Ce certificat est une AC, mais ne peut signer que des certificats finaux (aucune AC en dessous) |
| `keyUsage = critical,keyCertSign,cRLSign` | La clé ne sert qu'à signer des certificats et des CRL |
| `nameConstraints = critical,permitted;DNS:.tp.local,permitted;DNS:tp.local,permitted;email:tp.local` | Limite ce que l'intermédiaire peut valablement certifier : le domaine `tp.local` et ses sous-domaines (forme avec point initial et forme sans point, listées toutes deux) et les adresses email de `tp.local`. Le contrôle est fait par le client à la validation |
| `subjectKeyIdentifier = hash` | Identifiant de la clé publique du certificat |
| `authorityKeyIdentifier = keyid` | Identifiant de la clé de l'émetteur, inséré lorsqu'il est disponible : relie le certificat à son AC dans la chaîne |

`critical` signifie qu'un client qui ne comprend pas l'extension doit rejeter le certificat.

### Extensions des certificats finaux (`ext_serveur`, `ext_client`, dans `inter.cnf`)
| Ligne | Rôle |
|---|---|
| `basicConstraints = critical,CA:FALSE` | Certificat final : ne peut pas signer d'autres certificats |
| `keyUsage = critical,digitalSignature` | La clé sert à signer (suffisant pour une clé elliptique en TLS) |
| `extendedKeyUsage = serverAuth` (`ext_serveur`) | Certificat utilisable pour un serveur TLS |
| `extendedKeyUsage = clientAuth` (`ext_client`) | Certificat utilisable pour un client TLS |
| `subjectAltName = email:alice@tp.local` (`ext_client`) | Le certificat client porte toujours cette adresse en SAN, quelle que soit la CSR. Cette section ne convient donc qu'à Alice sans modification |
| `subjectKeyIdentifier` / `authorityKeyIdentifier` | Identification de la clé du certificat et de celle de son émetteur |

Le SAN du serveur ne figure pas dans `ext_serveur` : il vient de la CSR, grâce à `copy_extensions = copy`.

## Différences entre les deux fichiers
| Directive | `racine.cnf` | `inter.cnf` |
|---|---|---|
| `default_md` | sha384 | sha256 |
| `default_crl_days` | 30 | 7 |
| `copy_extensions` | none | copy |
| Extensions définies | `ext_inter` | `ext_serveur`, `ext_client` |

## Vérifications
    grep -c '\$dir' etape1-configuration/racine.cnf etape1-configuration/inter.cnf   # attendu : 6 et 6
    diff etape1-configuration/racine.cnf work/racine.cnf                              # attendu : aucune sortie
    cat work/racine/serial work/inter/serial                                          # attendu : 1000 puis 2000

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `$dir` remplacé par du vide dans le fichier | Guillemets oubliés autour de `'EOF'` | Recréer le fichier avec `<< 'EOF'` |
| Erreur de lecture sur `nameConstraints` | Ligne coupée en deux lors de la recopie | La ligne doit rester sur une seule ligne |
| Chemin `./racine/...` introuvable | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| `openssl ca` refuse de signer | `-days` oublié, les fichiers n'ont pas de `default_days` | Toujours passer `-days`, comme dans les commandes du sujet |
