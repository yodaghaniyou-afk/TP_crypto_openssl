# Étape 2 : AC racine

## Objectif
Créer l'autorité de certification racine : une clé privée P-384 et un certificat auto-signé valable 10 ans, avec les extensions imposées par le sujet (section 3.2).

## Prérequis
- Étape 1 réalisée (arborescence `work/` créée)
- OpenSSL 3.x

## Commandes exécutées
À lancer depuis `~/TP_crypto_openssl/work` :

    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 \
      -out racine/racine.key
    chmod 600 racine/racine.key

    openssl req -x509 -new -key racine/racine.key -sha384 -days 3650 \
      -subj "/C=BF/O=Universite TP/CN=Racine TP" \
      -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
      -addext "keyUsage=critical,keyCertSign,cRLSign" \
      -addext "subjectKeyIdentifier=hash" -out racine/racine.crt

    openssl x509 -in racine/racine.crt -noout -text

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `racine.crt` | Certificat public de la racine (peut être partagé) |
| `racine-crt-texte.txt` | Sortie complète de `openssl x509 -text` |

La clé privée `racine.key` reste dans `work/racine/` : elle est exclue du dépôt par `.gitignore` et ne doit jamais être publiée.

## Rôle des options
| Option | Rôle |
|---|---|
| `genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384` | Génère une clé privée elliptique sur la courbe P-384 |
| `req -x509 -new` | Crée directement un certificat auto-signé (sans passer par une CSR) |
| `-sha384` | Hachage utilisé pour la signature, adapté à une clé P-384 |
| `-days 3650` | Validité de 10 ans |
| `-subj` | Identité du certificat (pays, organisation, nom) |
| `basicConstraints=critical,CA:TRUE,pathlen:1` | AC autorisée à certifier une seule AC en dessous d'elle (l'intermédiaire) |
| `keyUsage=critical,keyCertSign,cRLSign` | La clé ne peut servir qu'à signer des certificats et des CRL |
| `subjectKeyIdentifier=hash` | Identifiant de la clé publique, utilisé pour relier la chaîne |

## Résultats observés
Extrait de `openssl x509 -in racine/racine.crt -noout -text` :

| Élément à repérer | Valeur obtenue |
|---|---|
| Émetteur (Issuer) | C=BF, O=Universite TP, CN=Racine TP |
| Sujet (Subject) | C=BF, O=Universite TP, CN=Racine TP |
| Validité | du 27 oct 2026 au 24 oct 2036 (GMT) |
| Algorithme de clé | id-ecPublicKey, courbe NIST P-384 |
| Algorithme de signature | ecdsa-with-SHA384 |
| Basic Constraints (critique) | CA:TRUE, pathlen:1 |
| Key Usage (critique) | Certificate Sign, CRL Sign |

## Interprétation
- **Émetteur = sujet** : la racine est auto-signée. Aucune autorité ne se trouve au-dessus d'elle, elle signe son propre certificat avec sa propre clé. Sa légitimité vient de l'installation préalable de son certificat dans le magasin de confiance des clients, pas d'une signature extérieure.
- **P-384 et SHA-384** : choix cohérent avec le tableau d'architecture du sujet, la racine étant l'élément le plus sensible et le plus durable de l'infrastructure.
- **pathlen:1** : la chaîne ne peut comporter qu'une AC intermédiaire sous la racine. Une AC de niveau inférieur serait refusée à la validation.
- **Extensions critiques** : un client qui ne reconnaît pas une extension marquée `critical` doit rejeter le certificat, ce qui empêche d'ignorer une restriction de sécurité.
- **Signature Algorithm apparaît deux fois** dans la sortie : une fois dans le corps du certificat (algorithme annoncé), une fois pour la signature elle-même. Les deux doivent être identiques.

## Vérifications
    openssl verify -CAfile racine/racine.crt racine/racine.crt
    # attendu : racine/racine.crt: OK

    ls -l racine/racine.key
    # attendu : -rw------- (lisible uniquement par le propriétaire)

    grep -rE "BEGIN [A-Z ]*PRIVATE" etape2-ac-racine
    # attendu : aucune sortie (aucune clé privée dans le dépôt)

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `No such file or directory: racine/racine.key` | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| `verify` affiche `self-signed certificate` en erreur | Option `-CAfile` oubliée | Ajouter `-CAfile racine/racine.crt` |
| Clé lisible par tous (`-rw-r--r--`) | `chmod 600` oublié | `chmod 600 racine/racine.key` |

## Réponse à la question du sujet
**Pourquoi l'émetteur et le sujet sont-ils identiques ?** Parce que la racine est le sommet de la chaîne : elle se certifie elle-même. C'est l'ancre de confiance de toute l'infrastructure.
