# Étape 3 : AC intermédiaire

## Objectif
Créer l'AC intermédiaire (clé P-256) et la faire signer par la racine, avec les extensions imposées par le sujet : `pathlen:0` et contraintes de nom limitées à `tp.local`.

## Prérequis
- Étapes 1 et 2 réalisées (racine créée dans `work/racine/`)
- Toutes les commandes se lancent depuis `~/TP_crypto_openssl/work`, car `racine.cnf` utilise des chemins relatifs (`./racine`)

## Remarque sur le sujet
Le sujet fournit la commande de signature, mais pas celles de la clé et de la CSR. Elles ont été écrites d'après le tableau d'architecture de la section 3.2 (clé P-256).

## Commandes exécutées
    # 1. Clé privée de l'intermédiaire (P-256)
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
      -out inter/inter.key
    chmod 600 inter/inter.key

    # 2. Demande de certificat (CSR)
    openssl req -new -key inter/inter.key -sha256 \
      -subj "/C=BF/O=Universite TP/CN=Intermediaire TP" \
      -out inter/inter.csr

    # 3. Signature par la racine (commande du sujet)
    openssl ca -batch -config racine.cnf -extensions ext_inter -days 1825 \
      -in inter/inter.csr -out inter/inter.crt

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `inter.crt` | Certificat public de l'intermédiaire, signé par la racine |
| `inter-crt-texte.txt` | Sortie complète de `openssl x509 -text` |

La clé privée `inter.key` et la CSR restent dans `work/inter/`, exclues du dépôt par `.gitignore`.

## Rôle des options
| Élément | Rôle |
|---|---|
| `req -new` | Crée une demande de certificat (CSR) : clé publique + identité, signées par la clé privée du demandeur |
| `ca -batch` | Signe sans demander de confirmation interactive |
| `-config racine.cnf` | La racine signe avec sa configuration et sa clé P-384 |
| `-extensions ext_inter` | Applique la section d'extensions de l'intermédiaire |
| `-days 1825` | Validité de 5 ans |

## Résultats observés
CSR : `openssl req -in inter/inter.csr -noout -verify -subject` a affiché `Certificate request self-signature verify OK` et `subject=C=BF, O=Universite TP, CN=Intermediaire TP`.

Signature : OpenSSL a affiché `Certificate is to be certified until Oct 26 03:32:44 2031 GMT (1825 days)`, puis `Write out database with 1 new entries` et `Database updated`.

Certificat (`openssl x509 -text`, extrait) :

| Élément | Valeur obtenue |
|---|---|
| Émetteur (Issuer) | C=BF, O=Universite TP, CN=Racine TP |
| Sujet (Subject) | C=BF, O=Universite TP, CN=Intermediaire TP |
| Validité | du 27 oct 2026 au 26 oct 2031 (GMT) |
| Courbe de la clé | NIST P-256 |
| Algorithme de signature | ecdsa-with-SHA384 |
| Basic Constraints (critique) | CA:TRUE, pathlen:0 |
| Key Usage (critique) | Certificate Sign, CRL Sign |
| Name Constraints (critique) | Permitted : DNS:tp.local, email:tp.local |

Base de la racine : `racine/index.txt` contient une ligne commençant par `V` (valide) pour `/C=BF/O=Universite TP/CN=Intermediaire TP`, avec le numéro de série `1000`. Le fichier `serial` est passé à `1001` et `racine/newcerts/1000.pem` existe.

## Interprétation
- **Émetteur ≠ sujet** : contrairement à la racine, l'intermédiaire n'est pas auto-signé. Sa légitimité vient de la signature de la racine, ce qui forme la chaîne de confiance.
- **Signature SHA-384 sur une clé P-256** : la signature est faite par la racine (clé P-384), le hachage suit donc la racine et non la clé de l'intermédiaire.
- **pathlen:0** : cette AC ne peut signer que des certificats finaux (serveur, client). Sans cette limite, une intermédiaire compromise pourrait créer de nouvelles AC.
- **Contraintes de nom critiques** : même si la clé de l'intermédiaire était volée, les certificats émis pour d'autres domaines que `tp.local` seront refusés par les clients à la validation.
- **Durée de 5 ans** : plus courte que la racine (10 ans). Un certificat ne peut pas durer plus longtemps que son émetteur.

## Vérifications
    openssl verify -CAfile racine/racine.crt inter/inter.crt
    # attendu : inter/inter.crt: OK

    openssl req -in inter/inter.csr -noout -verify -subject
    # attendu : verify OK et le sujet de l'intermédiaire

    grep -rE "BEGIN [A-Z ]*PRIVATE" etape3-ac-intermediaire
    # attendu : aucune sortie (aucune clé privée dans le dépôt)

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| Erreur sur un chemin `./racine/...` introuvable | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| `verify` affiche une erreur d'émetteur | Mauvais fichier passé à `-CAfile` | Utiliser `racine/racine.crt` |
| Clé privée lisible par tous | `chmod 600` oublié | `chmod 600 inter/inter.key` |
