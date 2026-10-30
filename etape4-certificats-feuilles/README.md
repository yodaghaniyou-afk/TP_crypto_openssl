# Étape 4 : Certificats de serveur et de client

## Objectif
Émettre, à partir de demandes de certificat (CSR), un certificat de serveur pour `www.tp.local` et un certificat de client pour `alice@tp.local`, tous deux signés par l'AC intermédiaire avec la configuration de l'annexe B.

## Prérequis
- Étapes 1 à 3 réalisées (fichiers de l'annexe B, intermédiaire signée par la racine)
- Toutes les commandes se lancent depuis `~/TP_crypto_openssl/work`

## Principe
Le demandeur génère lui-même sa clé privée et sa CSR. L'AC intermédiaire ne reçoit que la CSR (clé publique et identité) : elle ne voit jamais la clé privée du serveur ou du client.

## Remarques sur le sujet
- Les commandes du serveur sont celles du sujet.
- Pour le client, le sujet indique « faire de même avec la section `ext_client` ». La CSR d'Alice est donc créée sans noms alternatifs : l'adresse `email:alice@tp.local` est ajoutée par `ext_client` (annexe B), ce qui est vérifié dans les résultats.
- Ces certificats remplacent ceux d'une première version, émise avant la réception de l'annexe B.

## Commandes exécutées

### Serveur `www.tp.local`
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out serveur.key
    chmod 600 serveur.key
    openssl req -new -key serveur.key -subj "/CN=www.tp.local" \
      -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" -out serveur.csr
    openssl ca -batch -config inter.cnf -extensions ext_serveur -days 90 \
      -in serveur.csr -out serveur.crt

### Client `alice@tp.local`
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out alice.key
    chmod 600 alice.key
    openssl req -new -key alice.key -subj "/CN=alice@tp.local" -out alice.csr
    openssl ca -batch -config inter.cnf -extensions ext_client -days 90 \
      -in alice.csr -out alice.crt

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `serveur.crt` | Certificat public du serveur `www.tp.local` |
| `alice.crt` | Certificat public du client `alice@tp.local` |
| `serveur-crt-texte.txt` | Sortie complète de `openssl x509 -text` pour le serveur |
| `alice-crt-texte.txt` | Sortie complète de `openssl x509 -text` pour Alice |

Les clés privées (`serveur.key`, `alice.key`) et les CSR restent dans `work/`, exclues du dépôt par `.gitignore`.

## Résultats observés

| Élément | Serveur | Client |
|---|---|---|
| Émetteur | C=BF, O=Universite TP, CN=Intermediaire TP | idem |
| Sujet | CN=www.tp.local | CN=alice@tp.local |
| Validité | 30 oct 2026 10:07:31 au 28 janv 2027 10:07:31 GMT (90 jours) | idem |
| Courbe de la clé | NIST P-256 | NIST P-256 |
| Basic Constraints (critique) | CA:FALSE | CA:FALSE |
| Key Usage (critique) | Digital Signature | Digital Signature |
| Extended Key Usage | TLS Web Server Authentication | TLS Web Client Authentication |
| Noms alternatifs (SAN) | DNS:www.tp.local, DNS:tp.local | email:alice@tp.local |
| Numéro de série | 2000 | 2001 |

- Les deux CSR ont été contrôlées avec `openssl req -in ... -noout -verify -subject` : `Certificate request self-signature verify OK`.
- Les deux signatures ont affiché `Signature ok`, `(90 days)` et `Database updated`.
- `openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt` a donné `serveur.crt: OK` et `alice.crt: OK`.
- Les clés privées ont les droits `-rw-------`.
- Base de l'intermédiaire (`inter/index.txt`) : deux lignes commençant par `V` (valide), `/CN=www.tp.local` (série 2000) et `/CN=alice@tp.local` (série 2001). Le fichier `serial` vaut `2002`.

## Interprétation
- **CA:FALSE** : ces certificats sont des certificats finaux. Ils ne peuvent pas signer d'autres certificats, ce qui est cohérent avec `pathlen:0` sur l'intermédiaire.
- **Extended Key Usage différent** : c'est lui qui distingue le certificat de serveur du certificat de client. Un certificat de client ne peut pas servir de certificat de serveur, et inversement.
- **SAN du serveur** : il vient de la CSR. Il est présent dans le certificat grâce à `copy_extensions = copy` dans `inter.cnf` ; avec `none`, `openssl ca` l'ignorerait.
- **SAN d'Alice** : la CSR n'en contenait aucun, mais le certificat porte `email:alice@tp.local`. Il est imposé par la section `ext_client` de l'annexe B.
- **Numéros de série à partir de 2000** : le fichier `inter/serial` de l'intermédiaire démarre à 2000 (en hexadécimal), comme dans l'arborescence de l'annexe.
- **Durée de 90 jours** : plus courte que l'intermédiaire (5 ans) et la racine (10 ans). Une validité courte limite l'exposition en cas de compromission.
- **Contraintes de nom** : `www.tp.local`, `tp.local` et `alice@tp.local` appartiennent aux noms autorisés par l'intermédiaire.
- **Clé générée par le demandeur** : l'AC n'a jamais accès à la clé privée du serveur, qui n'a donc jamais besoin d'être transmise.

## Vérifications
    openssl req -in serveur.csr -noout -verify -subject
    openssl req -in alice.csr -noout -verify -subject
    openssl x509 -in serveur.crt -noout -text
    openssl x509 -in alice.crt -noout -text
    cat inter/index.txt

La validation de la chaîne complète est réalisée à l'étape 5.

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| Les noms alternatifs du serveur ont disparu | `copy_extensions = copy` absent de `inter.cnf` | Rétablir la directive et ré-émettre le certificat |
| Le certificat d'Alice porte toujours `alice@tp.local` | Le SAN est fixé dans `ext_client` | Prévoir une autre section pour un autre client |
| Erreur sur un chemin `./inter/...` introuvable | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| Certificat signé par la racine au lieu de l'intermédiaire | `-config racine.cnf` utilisé par erreur | Utiliser `-config inter.cnf` |
