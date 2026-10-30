# Étape 7 : Automatiser avec `pki.sh`

## Objectif
Regrouper les étapes 2 à 4 (AC racine, AC intermédiaire, certificat de serveur, certificat de client) dans un script qui s'arrête à la première erreur.

## Prérequis
- Étape 1 réalisée : le script lit `racine.cnf` et `inter.cnf` (annexe B) dans `etape1-configuration/`
- OpenSSL 3.x, bash

## Commandes d'exécution
Depuis la racine du dépôt :

    bash etape7-automatisation/pki.sh

Le script construit tout dans `work/pki-auto` (dossier exclu de Git). Un autre dossier peut être indiqué en argument :

    bash etape7-automatisation/pki.sh /chemin/vers/un/dossier

## Fichiers de ce dossier
| Fichier | Rôle |
|---|---|
| `pki.sh` | Script d'automatisation |
| `execution-1er-lancement.log` | Sortie réelle du premier lancement |
| `execution-2e-lancement.log` | Sortie réelle du second lancement (échec volontaire) |

## Fonctionnement du script
| Élément | Rôle |
|---|---|
| `set -euo pipefail` | `-e` : arrêt à la première commande en erreur. `-u` : erreur si une variable n'est pas définie. `pipefail` : une erreur au milieu d'un enchaînement par tube est aussi détectée |
| Contrôle de `$BUILD_DIR` | Refuse de s'exécuter si le dossier existe déjà, pour ne jamais écraser une PKI ou ses clés privées |
| Contrôle des `.cnf` | Vérifie que les deux fichiers de configuration existent avant de commencer |
| Préparation | Crée l'arborescence de l'annexe B : `certs`, `crl`, `newcerts`, `index.txt`, `serial` et `crlnumber` (1000 pour la racine, 2000 pour l'intermédiaire) |
| Étapes 2 à 4 | Rejoue les commandes du sujet : racine P-384, intermédiaire P-256, serveur `www.tp.local`, client `alice@tp.local` |
| CSR d'Alice | Créée sans noms alternatifs : l'adresse `email:alice@tp.local` est ajoutée par la section `ext_client` de l'annexe B |
| Vérification finale | Valide le serveur (avec son nom) et le client (usage `sslclient`) |

Le script ne reprend pas les étapes 5 (validations commentées) et 6 (révocation), conformément au sujet qui demande de regrouper les étapes 2 à 4.

## Résultats observés
| Test | Résultat obtenu |
|---|---|
| Syntaxe (`bash -n pki.sh`) | `syntaxe OK` |
| 1er lancement | Code de sortie `0` ; fin de sortie : `serveur.crt: OK`, `alice.crt: OK`, `==> PKI generee dans .../work/pki-auto` |
| 2e lancement (dossier déjà présent) | Code de sortie `1` ; message : `Erreur : .../work/pki-auto existe deja. Supprimez-le ou indiquez un autre dossier.` |

Contrôle de la PKI générée par le script :

| Élément | Résultat obtenu |
|---|---|
| Numéro de série du serveur | 2000 |
| Numéro de série d'Alice | 2001 |
| SAN du certificat d'Alice | `email:alice@tp.local` (absent de sa CSR : ajouté par `ext_client`) |
| Contraintes de nom de l'intermédiaire | Permitted : `DNS:.tp.local`, `DNS:tp.local`, `email:tp.local` |
| Base de l'intermédiaire (`inter/index.txt`) | Deux lignes `V` : `/CN=www.tp.local` (2000) et `/CN=alice@tp.local` (2001) |

## Interprétation
- **Code de sortie 0 puis 1 :** le script signale par son code de sortie s'il a réussi (0) ou échoué (1), ce qui le rend utilisable dans une chaîne d'automatisation.
- **Arrêt immédiat :** lors du second lancement, le script s'arrête avant de créer la moindre clé, grâce au contrôle du dossier. Aucune clé existante n'est écrasée.
- **Résultat identique à la construction manuelle :** les mêmes noms, extensions, contraintes de nom et numéros de série (2000 et 2001) que les étapes 3 et 4, ce qui confirme que le script reproduit fidèlement les commandes.
- **Dossier séparé :** la PKI générée par le script est distincte de celle construite à la main, qui reste intacte.
- **Clés privées :** elles restent dans `work/pki-auto`, exclu du dépôt par `.gitignore`.

## Vérifications
    bash -n etape7-automatisation/pki.sh && echo "syntaxe OK"
    bash etape7-automatisation/pki.sh ; echo "code de sortie : $?"
    grep -rE "BEGIN [A-Z ]*PRIVATE" etape7-automatisation   # attendu : aucune sortie

## Erreurs fréquentes
| Problème | Cause | Solution |
|---|---|---|
| `existe deja` | Une PKI est déjà présente dans le dossier cible | Supprimer le dossier (`rm -rf work/pki-auto`) ou passer un autre dossier en argument |
| `racine.cnf introuvable` | Étape 1 non réalisée ou script déplacé | Garder `pki.sh` dans `etape7-automatisation/` à côté de `etape1-configuration/` |
| `command not found: openssl` | OpenSSL non installé | Installer OpenSSL 3.x |
| `Permission denied` | Script non exécutable | Lancer avec `bash pki.sh` |
