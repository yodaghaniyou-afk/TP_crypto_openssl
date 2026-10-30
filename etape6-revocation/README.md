# Étape 6 : Révoquer un certificat et publier une CRL

## Objectif
Simuler la compromission de la clé d'Alice : révoquer son certificat, publier les listes de révocation (CRL) de l'intermédiaire et de la racine, puis vérifier que le certificat est refusé.

## Prérequis
- Étapes 1 à 5 réalisées (configuration de l'annexe B)
- Commandes lancées depuis `~/TP_crypto_openssl/work`

## Remarque
Cette étape a été rejouée avec les fichiers de l'annexe B : la CRL de l'intermédiaire dure 7 jours (`default_crl_days = 7`) et le certificat d'Alice porte le numéro de série 2001. Elle remplace une première version.

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
| `resultats-revocation.txt` | Sorties réelles : révocation, génération des CRL, base, deux vérifications, contenu des deux CRL |

## Résultats observés
| Élément | Résultat obtenu |
|---|---|
| Révocation | `Revoking Certificate 2001.` puis `Database updated` |
| Base de l'intermédiaire | Série 2000 (`www.tp.local`) en `V`, série 2001 (`alice@tp.local`) en `R` avec `keyCompromise` (30 oct 2026 21:39:09 GMT), série 2002 (`www.example.com`) en `V` |
| Test 1 : `alice.crt` avec CRL | `error 23 at 0 depth lookup: certificate revoked` puis `verification failed` |
| Test 2 (contrôle) : `serveur.crt` avec CRL | `serveur.crt: OK` |
| CRL de l'intermédiaire | Émetteur `Intermediaire TP`, `CRL Number: 8192`, une entrée : série 2001, `Key Compromise`, révoquée le 30 oct 2026 21:39:09 GMT |
| Validité de la CRL de l'intermédiaire | Last Update 30 oct 2026 21:39:09, Next Update 6 nov 2026 21:39:09 (7 jours) |
| CRL de la racine | Émetteur `Racine TP`, `CRL Number: 4096`, `No Revoked Certificates` |
| Validité de la CRL de la racine | Last Update 30 oct 2026 21:39:09, Next Update 29 nov 2026 21:39:09 (30 jours) |
| Signatures | CRL de l'intermédiaire : ecdsa-with-SHA256 ; CRL de la racine : ecdsa-with-SHA384 |

Les numéros de CRL sont lus en décimal : 8192 et 4096 correspondent à 2000 et 1000 en hexadécimal, valeurs initiales des fichiers `crlnumber`.

## Interprétation
- **Test 1 :** la signature d'Alice est correcte, mais la CRL de l'intermédiaire la déclare révoquée. Le refus vient de la CRL, non de la chaîne. `at 0 depth` : l'erreur est relevée sur le certificat final.
- **Test 2 :** le certificat du serveur passe malgré le contrôle des CRL, ce qui montre que la révocation ne touche que le certificat concerné.
- **Deux CRL :** `-crl_check_all` exige une CRL pour chaque niveau de la chaîne. La racine n'a rien révoqué, sa CRL est donc vide, mais elle doit exister.
- **Durées différentes :** la CRL de l'intermédiaire, qui change souvent, est valable 7 jours ; celle de la racine, qui change rarement, 30 jours. Un client qui garde une ancienne CRL peut ignorer une révocation récente jusqu'à sa date de fin : plus la durée est courte, plus l'exposition est réduite, au prix de publications plus fréquentes.
- **Raison `keyCompromise`** : elle est inscrite dans l'entrée de la CRL, ce qui renseigne les clients sur la cause de la révocation.

## Vérifications
    cat etape6-revocation/resultats-revocation.txt
    grep -rE "BEGIN [A-Z ]*PRIVATE" etape6-revocation   # attendu : aucune sortie

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `unable to get certificate CRL` | CRL de la racine absente de `crls.pem` | Régénérer les deux CRL et refaire le `cat` |
| `already revoked` | Certificat déjà révoqué | Vérifier la base avec `cat inter/index.txt` |
| La révocation ne change rien au test | CRL non régénérée après `-revoke` | Relancer `ca -gencrl` pour chaque AC |
