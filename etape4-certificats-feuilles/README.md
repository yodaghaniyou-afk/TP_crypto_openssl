# Étape 4 : Certificats de serveur et de client

## Objectif
Émettre, à partir de demandes de certificat (CSR), un certificat de serveur pour `www.tp.local` et un certificat de client pour `alice@tp.local`, tous deux signés par l'AC intermédiaire.

## Prérequis
- Étapes 1 à 3 réalisées (intermédiaire signée par la racine)
- Toutes les commandes se lancent depuis `~/TP_crypto_openssl/work`

## Principe
Le demandeur génère lui-même sa clé privée et sa CSR. L'AC intermédiaire ne reçoit que la CSR (clé publique et identité) : elle ne voit jamais la clé privée du serveur ou du client.

## Remarque sur le sujet
Le sujet donne les commandes du serveur. Pour le client il indique « faire de même avec la section `ext_client` » : les commandes d'Alice ci-dessous sont une adaptation. L'adresse email d'Alice a été placée dans les noms alternatifs (SAN), car les contraintes de nom de l'intermédiaire portent sur les emails de `tp.local`.

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
    openssl req -new -key alice.key -subj "/CN=alice@tp.local" \
      -addext "subjectAltName=email:alice@tp.local" -out alice.csr
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
| Validité | 27 oct 2026 au 25 janv 2027 (90 jours) | 27 oct 2026 au 25 janv 2027 (90 jours) |
| Courbe de la clé | NIST P-256 | NIST P-256 |
| Basic Constraints (critique) | CA:FALSE | CA:FALSE |
| Key Usage (critique) | Digital Signature | Digital Signature |
| Extended Key Usage | TLS Web Server Authentication | TLS Web Client Authentication |
| Noms alternatifs (SAN) | DNS:www.tp.local, DNS:tp.local | email:alice@tp.local |
| Numéro de série | 1000 | 1001 |

Les deux CSR ont été contrôlées avec `openssl req -in ... -noout -verify -subject` : `Certificate request self-signature verify OK`.

Base de l'intermédiaire (`inter/index.txt`) : deux lignes commençant par `V` (valide), `/CN=www.tp.local` (série 1000) et `/CN=alice@tp.local` (série 1001). Le fichier `serial` vaut `1002`, et `inter/newcerts` contient `1000.pem` et `1001.pem`.

## Interprétation
- **CA:FALSE** : ces certificats sont des certificats finaux. Ils ne peuvent pas signer d'autres certificats, ce qui est cohérent avec `pathlen:0` sur l'intermédiaire.
- **Extended Key Usage différent** : c'est lui qui distingue le certificat de serveur du certificat de client. Un certificat de client ne peut pas être présenté comme certificat de serveur, et inversement.
- **SAN conservés** : les noms alternatifs de la CSR sont présents dans le certificat grâce à `copy_extensions = copy` dans `inter.cnf`. Sans cette directive, `openssl ca` ignore les extensions de la CSR.
- **Durée de 90 jours** : plus courte que celle de l'intermédiaire (5 ans) et de la racine (10 ans). Une validité courte limite la durée d'exposition en cas de compromission.
- **Contraintes de nom** : `www.tp.local`, `tp.local` et `alice@tp.local` appartiennent au domaine `tp.local` autorisé par l'intermédiaire.
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
| Les noms alternatifs ont disparu du certificat | `copy_extensions = copy` absent de `inter.cnf` | Ajouter la directive et ré-émettre le certificat |
| Erreur sur un chemin `./inter/...` introuvable |
## Interprétation
- **CA:FALSE** : ces certificats sont des certificats finaux. Ils ne peuvent pas signer d'autres certificats, ce qui est cohérent avec `pathlen:0` sur l'intermédiaire.
- **Extended Key Usage différent** : c'est lui qui distingue le certificat de serveur du certificat de client. Un certificat de client ne peut pas être présenté comme certificat de serveur, et inversement.
- **SAN conservés** : les noms alternatifs de la CSR sont présents dans le certificat grâce à `copy_extensions = copy` dans `inter.cnf`. Sans cette directive, `openssl ca` ignore les extensions de la CSR.
- **Durée de 90 jours** : plus courte que celle de l'intermédiaire (5 ans) et de la racine (10 ans). Une validité courte limite la durée d'exposition en cas de compromission.
- **Contraintes de nom** : `www.tp.local`, `tp.local` et `alice@tp.local` appartiennent au domaine `tp.local` autorisé par l'intermédiaire.
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
| Les noms alternatifs ont disparu du certificat | `copy_extensions = copy` absent de `inter.cnf` | Ajouter la directive et ré-émettre le certificat |
| Erreur sur un chemin `./inter/...` introuvable | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| Certificat signé par la racine au lieu de l'intermédiaire | `-config racine.cnf` utilisé par erreur | Utiliser `-config inter.cnf` |
