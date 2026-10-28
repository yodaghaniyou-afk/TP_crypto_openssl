# TP 2 : Infrastructure de gestion de clés avec OpenSSL

Module EC1 – Ingénierie de la cryptographie (Dr. Zakaria Sawadogo), année universitaire 2026–2027.
Auteur : YODA Abdoul Ghaniyou

## Objectif
Construire une infrastructure de gestion de clés (PKI) avec OpenSSL : AC racine, AC intermédiaire, certificats de serveur et de client, validation de chaîne, révocation avec CRL, et automatisation par script.

## Environnement utilisé
| Élément | Valeur |
|---|---|
| Système | Kali Linux (machine virtuelle) |
| OpenSSL | 3.5.4 |
| Git | 2.47.2 |

## Architecture réalisée
| Élément | Clé et durée | Extensions essentielles |
|---|---|---|
| AC racine | P-384, 10 ans | CA:TRUE, pathlen:1 ; keyCertSign, cRLSign |
| AC intermédiaire | P-256, 5 ans | CA:TRUE, pathlen:0 ; contraintes de nom : DNS:tp.local et email:tp.local |
| Serveur `www.tp.local` | P-256, 90 jours | CA:FALSE ; serverAuth ; SAN : www.tp.local et tp.local |
| Client `alice@tp.local` | P-256, 90 jours | CA:FALSE ; clientAuth ; SAN : alice@tp.local |

## Structure du dépôt
    TP_crypto_openssl/
    ├── README.md
    ├── .gitignore
    ├── etape1-configuration/
    ├── etape2-ac-racine/
    ├── etape3-ac-intermediaire/
    ├── etape4-certificats-feuilles/
    ├── etape5-validation/
    ├── etape6-revocation/
    ├── etape7-automatisation/
    └── questions-reflexion/

Chaque dossier contient son propre `README.md` : objectif, commandes exactes, rôle des fichiers, résultats observés, interprétation, vérifications et erreurs fréquentes.

## Conformité au sujet
| Demande du sujet | Dossier | Barème |
|---|---|---|
| Fichiers de configuration `racine.cnf` et `inter.cnf` | [etape1-configuration](etape1-configuration/) | |
| AC racine | [etape2-ac-racine](etape2-ac-racine/) | racine et intermédiaire (5) |
| AC intermédiaire | [etape3-ac-intermediaire](etape3-ac-intermediaire/) | racine et intermédiaire (5) |
| Certificats de serveur et de client | [etape4-certificats-feuilles](etape4-certificats-feuilles/) | certificats feuilles (4) |
| Validations commentées | [etape5-validation](etape5-validation/) | validations commentées (4) |
| Révocation et CRL | [etape6-revocation](etape6-revocation/) | révocation (3) |
| Script `pki.sh` | [etape7-automatisation](etape7-automatisation/) | script (1) |
| Questions de réflexion et compte rendu | [questions-reflexion](questions-reflexion/) | questions (3) |

## Reproduire le travail

### Méthode rapide (script)
    git clone https://github.com/yodaghaniyou-afk/TP_crypto_openssl.git
    cd TP_crypto_openssl
    bash etape7-automatisation/pki.sh

Le script reconstruit toute l'infrastructure (racine, intermédiaire, serveur, client) dans `work/pki-auto`, à partir des fichiers de `etape1-configuration/`.

### Méthode pas à pas
Suivre les README des dossiers `etape1` à `etape6`, dans l'ordre. Les commandes se lancent depuis le dossier `work/` (non versionné).

## Résultats principaux
| Élément | Résultat observé |
|---|---|
| Racine | Auto-signée (émetteur = sujet), P-384, ecdsa-with-SHA384, du 27 oct 2026 au 24 oct 2036 |
| Intermédiaire | Signée par la racine, P-256, du 27 oct 2026 au 26 oct 2031, `CA:TRUE, pathlen:0`, contraintes de nom critiques |
| Serveur et client | Signés par l'intermédiaire, 90 jours, `CA:FALSE`, usages `serverAuth` et `clientAuth` |
| Validations (étape 5) | Bon nom : OK ; mauvais nom : `hostname mismatch` ; client : OK ; hors `tp.local` : `permitted subtree violation` |
| Révocation (étape 6) | Certificat d'Alice (série 1001) révoqué (`keyCompromise`) ; refusé avec `certificate revoked` ; certificat du serveur toujours accepté |
| Script (étape 7) | 1er lancement : code 0, chaînes valides ; 2e lancement : code 1, refus d'écraser une PKI existante |

## Remarques sur le sujet
- L'annexe B (fichiers de configuration fournis) ne figurait pas dans le PDF reçu : `racine.cnf` et `inter.cnf` ont été rédigés d'après le tableau d'architecture de la section 3.2.
- Le sujet ne détaille pas la clé et la CSR de l'intermédiaire, ni les commandes du client Alice : elles sont adaptées de celles du serveur.
- Ajouts personnels : `chmod 600` sur les clés privées, un test de contrôle à l'étape 6 (le certificat du serveur reste valide après la révocation d'Alice), et un certificat de test `www.example.com` pour l'étape 5.

## Sécurité
- Aucune clé privée n'est versionnée : `.gitignore` exclut `*.key`, `private/` et le dossier de travail `work/`.
- Seuls les certificats et les CRL (documents publics) sont publiés.
- Avant chaque commit, une recherche d'en-tête de clé privée PEM a été lancée sur le dossier concerné.
- Les clés privées sont créées avec les droits `600` (lecture par le propriétaire seul).

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| Fichiers introuvables à la réouverture de la machine | Terminal ouvert avec un autre utilisateur que celui du TP | Repasser en `root` (`sudo -i`), puis `cd ~/TP_crypto_openssl/work` |
| Erreur de chemin `./racine/...` ou `./inter/...` | Commande lancée hors de `work/` | `cd ~/TP_crypto_openssl/work` |
| `pki.sh` : `existe deja` | Une PKI est déjà présente dans le dossier cible | Supprimer `work/pki-auto` ou indiquer un autre dossier |
| `verification failed` aux tests 2 et 4 de l'étape 5 | Résultat attendu : ces tests prouvent le refus d'un mauvais nom et d'un nom hors domaine | Voir le README de l'étape 5 |
