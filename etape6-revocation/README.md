# Étape 6 : Révoquer un certificat et publier une CRL

## Objectif
Simuler la compromission de la clé d'Alice : révoquer son certificat, publier les listes de révocation (CRL) de l'intermédiaire et de la racine, puis vérifier que le certificat est refusé.

## Prérequis
- Étapes 1 à 5 réalisées
- Commandes lancées depuis `~/TP_crypto_openssl/work`

## Commandes exécutées
    openssl ca -config inter.cnf -revoke alice.crt -crl_reason keyCompromise
    openssl ca -config inter.cnf -gencrl -out inter/crl/inter.crl
    openssl ca -config racine.cnf -gencrl -out racine/crl/racine.crl
    cat inter/crl/inter.crl racine/crl/racine.crl > crls.pem
    openssl verify -crl_check_all -CRLfile crls.pem -CAfile racine/racine.crt \
      -untrusted inter/inter.crt alice.crt
    openssl crl -in inter/crl/inter.crl -noout -text

## Rôle des commandes
| Commande | Rôle |
|---|---|
| `ca -revoke ... -crl_reason keyCompromise` | Marque le certificat comme révoqué dans la base de l'intermédiaire, avec la raison « clé compromise » |
| `ca -gencrl` | Génère la liste des certificats révoqués, signée par l'AC |
| `cat ... > crls.pem` | Regroupe les deux CRL, car `-crl_check_all` contrôle toute la chaîne (intermédiaire et racine) |
| `verify -crl_check_all -CRLfile` | Vérifie la chaîne en consultant les CRL |
| `crl -noout -text` | Affiche le contenu lisible d'une CRL |

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `inter.crl` | CRL de l'intermédiaire (contient le certificat d'Alice) |
| `racine.crl` | CRL de la racine (aucune révocation à ce niveau) |
| `resultats-revocation.txt` | Sorties réelles des vérifications, enregistrées par un script |

## Résultats observés
| Élément | Résultat obtenu |
|---|---|
| Révocation | `Revoking Certificate 1001.` puis `Database updated` |
| Base de l'intermédiaire | Ligne d'Alice passée de `V` à `R` avec `keyCompromise` ; `www.tp.local` reste en `V` |
| Test 1 : `alice.crt` avec CRL | `error 23 at 0 depth lookup: certificate revoked` puis `verification failed` |
| Test 2 (contrôle) : `serveur.crt` avec CRL | `serveur.crt: OK` |
| CRL de l'intermédiaire | Émetteur `Intermediaire TP`, une entrée : série 1001, `Key Compromise`, révoqué le 28 oct 2026 01:57:42 GMT |
| Validité de la CRL | Last Update 28 oct 2026, Next Update 27 nov 2026 (30 jours) |
| Signature de la CRL | ecdsa-with-SHA256 (algorithme de l'intermédiaire) |

Le certificat de test `www.example.com` (série 1002, étape 5) reste marqué `V` : il n'a pas été révoqué.

## Interprétation
- **Test 1 :** la signature d'Alice est correcte, mais la CRL de l'intermédiaire la déclare révoquée. Le refus vient de la CRL, non de la chaîne. `at 0 depth` : l'erreur est relevée sur le certificat final.
- **Test 2 :** le certificat du serveur passe malgré le contrôle des CRL, ce qui montre que la révocation ne touche que le certificat concerné.
- **Deux CRL :** `-crl_check_all` exige une CRL pour chaque niveau de la chaîne. La racine n'a rien révoqué, sa CRL est donc vide, mais elle doit exister.
- **Durée de 30 jours** (`default_crl_days`) : un client qui n'actualise pas sa CRL peut ignorer une révocation récente pendant cette durée. C'est une limite des CRL.

## Vérifications
    cat etape6-revocation/resultats-revocation.txt
    grep -rE "BEGIN [A-Z ]*PRIVATE" etape6-revocation   # attendu : aucune sortie

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `unable to get certificate CRL` | CRL de la racine absente de `crls.pem` | Régénérer les deux CRL et refaire le `cat` |
| `already revoked` | Certificat déjà révoqué | Vérifier la base avec `cat inter/index.txt` |
| La révocation ne change rien au test | CRL non régénérée après `-revoke` | Relancer `ca -gencrl` pour chaque AC |
