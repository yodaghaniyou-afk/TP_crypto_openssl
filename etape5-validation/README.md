# Étape 5 : Valider les chaînes de certificats

## Objectif
Exécuter et interpréter les validations demandées par le sujet : un certificat de serveur avec le bon puis un mauvais nom, un certificat de client avec l'usage « client TLS », et un certificat hors du domaine autorisé par les contraintes de nom de l'intermédiaire.

## Prérequis
- Étapes 1 à 4 réalisées (configuration de l'annexe B)
- Commandes lancées depuis `~/TP_crypto_openssl/work`

## Remarque
Ces validations ont été rejouées avec l'intermédiaire, le serveur et le client émis avec les fichiers de l'annexe B. Elles remplacent celles d'une première version.

## Commandes exécutées
    # Test 1 : serveur, bon nom (attendu : OK)
    openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
      -verify_hostname www.tp.local serveur.crt

    # Test 2 : serveur, mauvais nom (attendu : échec)
    openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
      -verify_hostname autre.example serveur.crt

    # Test 3 : client, usage sslclient (attendu : OK)
    openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
      -purpose sslclient alice.crt

    # Test 4 : certificat pour www.example.com (attendu : échec)
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out exemple.key
    openssl req -new -key exemple.key -subj "/CN=www.example.com" \
      -addext "subjectAltName=DNS:www.example.com" -out exemple.csr
    openssl ca -batch -config inter.cnf -extensions ext_serveur -days 90 \
      -in exemple.csr -out exemple.crt
    openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt exemple.crt

## Rôle des options de `openssl verify`
| Option | Rôle |
|---|---|
| `-CAfile racine/racine.crt` | Désigne la racine comme ancre de confiance |
| `-untrusted inter/inter.crt` | Fournit l'intermédiaire comme maillon de la chaîne, sans lui accorder de confiance en soi |
| `-verify_hostname` | Vérifie que le nom demandé figure dans les noms alternatifs (SAN) du certificat |
| `-purpose sslclient` | Vérifie que le certificat est utilisable comme certificat de client TLS |

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `resultats-validation.txt` | Sorties réelles de l'émission du certificat de test et des 4 validations, enregistrées par un script |

Les fichiers du test 4 (`exemple.key`, `exemple.csr`, `exemple.crt`) restent dans `work/` : ce sont des fichiers de test, pas des livrables.

## Résultats observés
| Test | Commande (résumé) | Résultat obtenu | Attendu |
|---|---|---|---|
| Émission | `ca -config inter.cnf -extensions ext_serveur` pour `www.example.com` | `Signature ok`, `(90 days)`, `Database updated` (série 2002) | signature réussie |
| 1 | `verify -verify_hostname www.tp.local serveur.crt` | `serveur.crt: OK` | OK |
| 2 | `verify -verify_hostname autre.example serveur.crt` | `error 62 at 0 depth lookup: hostname mismatch` puis `verification failed` | échec |
| 3 | `verify -purpose sslclient alice.crt` | `alice.crt: OK` | OK |
| 4 | `verify exemple.crt` (`www.example.com`) | `error 47 at 0 depth lookup: permitted subtree violation` puis `verification failed` | échec |

Le détail complet est dans `resultats-validation.txt`. La base de l'intermédiaire contient trois lignes `V` : `www.tp.local` (série 2000), `alice@tp.local` (série 2001) et `www.example.com` (série 2002).

## Interprétation
- **Test 1 : OK.** La chaîne `serveur.crt` → intermédiaire → racine est valide : chaque signature est correcte, les dates sont valides, la racine est l'ancre de confiance, et le nom `www.tp.local` figure dans les noms alternatifs.
- **Test 2 : `error 62`.** La chaîne est identique, mais `autre.example` ne figure dans aucun nom alternatif du certificat. Le certificat est refusé pour ce nom : un client vérifie le nom du serveur en plus de la signature.
- **Test 3 : OK.** Le certificat d'Alice porte l'extension `TLS Web Client Authentication` : il est utilisable comme certificat de client TLS.
- **Test 4 : `error 47`.** Le certificat de `www.example.com` est correctement signé par l'intermédiaire, mais son nom sort des noms autorisés par le certificat de l'intermédiaire (`DNS:.tp.local`, `DNS:tp.local`, `email:tp.local`). La validation le refuse, avec `at 0 depth` : l'erreur est relevée sur le certificat final.

## Réponse à la question du sujet
**Pourquoi l'AC a-t-elle pu signer ce certificat alors qu'il est refusé à la validation ?**
`openssl ca` a signé `www.example.com` sans erreur, alors que `openssl verify` l'a refusé. Les contraintes de nom sont inscrites dans le certificat de l'intermédiaire et sont appliquées par celui qui **valide** la chaîne (le client), non par `openssl ca` au moment de signer. Si la clé de l'intermédiaire était volée, les certificats émis hors de `tp.local` seraient quand même refusés par les clients.

## Vérifications
    cat etape5-validation/resultats-validation.txt
    grep -rE "BEGIN [A-Z ]*PRIVATE" etape5-validation   # attendu : aucune sortie

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `unable to get local issuer certificate` | `-untrusted inter/inter.crt` oublié | Ajouter l'intermédiaire avec `-untrusted` |
| `No such file or directory` sur un `.crt` | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| `hostname mismatch` alors que le nom semble bon | Nom absent des noms alternatifs (SAN) | Vérifier le SAN avec `openssl x509 -noout -text` |
