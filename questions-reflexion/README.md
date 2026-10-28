# Questions de réflexion du TP 2

Les réponses s'appuient sur l'infrastructure construite dans les étapes 1 à 7 : racine P-384 (10 ans), intermédiaire P-256 (5 ans, `pathlen:0`, contraintes de nom `tp.local`), certificats finaux de 90 jours.

## 1. Pourquoi la clé de la racine doit-elle rester hors ligne ? Que faire si l'intermédiaire est compromis ? Et la racine ?

La clé de la racine est l'ancre de confiance de toute l'infrastructure : celui qui la détient peut émettre n'importe quel certificat accepté par tous les clients qui font confiance à la racine. Elle ne sert que rarement (signer l'intermédiaire et les CRL de la racine). La garder hors ligne, sur une machine non connectée au réseau et stockée en lieu sûr, supprime la possibilité de la voler à distance.

- **Intermédiaire compromis :** la racine révoque le certificat de l'intermédiaire dans sa CRL. On crée une nouvelle intermédiaire avec une nouvelle clé, on réémet les certificats finaux qu'elle avait signés, et on publie des CRL à jour. La racine ne change pas : les clients gardent leur ancre de confiance.
- **Racine compromise :** c'est le cas le plus grave. Une racine auto-signée n'a aucune autorité au-dessus d'elle pour la révoquer. Il faut la retirer de tous les magasins de confiance, distribuer une nouvelle racine (nouvelle clé), puis reconstruire toute la chaîne : intermédiaires et certificats finaux.

## 2. À quoi sert `pathlen:0` sur l'intermédiaire ? Quel risque si on l'oublie ?

`pathlen:0` interdit toute autre AC sous l'intermédiaire : elle ne peut signer que des certificats finaux. Sans cette limite, une intermédiaire compromise ou mal utilisée pourrait créer des sous-AC, qui émettraient à leur tour des certificats : la surface à contrôler grandirait et la révocation deviendrait plus difficile à maîtriser.

Dans notre architecture, `pathlen:1` sur la racine limite déjà la profondeur à une seule intermédiaire. D'après la définition de `pathlen`, une sous-AC sous l'intermédiaire dépasserait cette limite. Ici, `pathlen:0` est donc une défense en profondeur : il garde son effet même si le certificat de l'intermédiaire est vérifié dans un autre contexte que celui de notre racine.

## 3. Pourquoi la clé privée du serveur est-elle générée par le serveur et non par l'AC ?

Si l'AC générait la clé, elle devrait la transmettre au serveur et la conserver un temps, ce qui multiplie les occasions de fuite (transfert, copies, sauvegardes). En la générant lui-même, le serveur ne la communique jamais : l'AC ne reçoit que la CSR (clé publique et identité). Dans ce TP, c'est ce qui a été fait : `serveur.key` et `alice.key` n'ont jamais quitté `work/`.

La CSR est signée avec la clé privée : cela prouve que le demandeur la possède. Enfin, une AC qui connaîtrait les clés privées de ses clients pourrait se faire passer pour eux.

## 4. Le CN et le SAN contiennent tous deux `www.tp.local`. Lequel les clients modernes vérifient-ils ?

Les clients modernes vérifient le **SAN** (noms alternatifs du sujet). Le CN est un usage historique : lorsque le certificat possède un SAN, les navigateurs actuels ignorent le CN pour valider le nom d'hôte. C'est pourquoi les commandes de ce TP demandent explicitement `subjectAltName=DNS:www.tp.local,DNS:tp.local`, et pourquoi `inter.cnf` contient `copy_extensions = copy`, qui recopie le SAN de la CSR dans le certificat. Au test 2 de l'étape 5, `autre.example` a été refusé (`hostname mismatch`) faute de correspondance dans les noms alternatifs.

## 5. Quelles sont les limites des CRL ? Comparaison avec OCSP et avec des certificats de très courte durée.

**Limites des CRL :**
- La liste grossit avec le nombre de révocations et doit être téléchargée en entier.
- Sa fraîcheur dépend de la périodicité de publication : ici la CRL est valable 30 jours, donc une révocation récente peut passer inaperçue d'un client qui garde une ancienne copie.
- Le client doit pouvoir la récupérer, et beaucoup de clients acceptent le certificat si la CRL est introuvable.

**OCSP** (Online Certificate Status Protocol) : le client demande l'état d'un seul certificat à un répondeur. La réponse est petite et à jour. En contrepartie, le répondeur doit être disponible, il apprend quels certificats le client consulte (confidentialité), et si le répondeur ne répond pas, les clients acceptent souvent le certificat quand même. L'agrafage OCSP (le serveur joint lui-même la réponse signée) atténue ces défauts.

**Certificats de très courte durée :** l'expiration remplace la révocation : un certificat volé devient inutilisable en quelques jours, sans interroger personne. Cela exige en contrepartie un renouvellement automatisé et fiable, ce qui prépare le TP 3.

## 6. Politique de certification minimale (10 lignes) — proposition

1. **Périmètre :** l'infrastructure `tp.local` du laboratoire (racine, intermédiaire, certificats de serveur et de client).
2. **Demandeurs :** étudiants et enseignants du laboratoire, pour des machines ou adresses dont ils ont la responsabilité, uniquement sur `tp.local` (contrainte de nom de l'intermédiaire).
3. **Identité :** le demandeur justifie son identité et la maîtrise du nom demandé auprès de l'administrateur de l'AC avant toute signature.
4. **Clés :** générées par le demandeur (P-256 au minimum), jamais transmises ; seule la CSR est envoyée à l'AC.
5. **Racine :** P-384, validité 10 ans, clé hors ligne, utilisée uniquement pour signer l'intermédiaire et ses CRL.
6. **Intermédiaire :** P-256, validité 5 ans, `pathlen:0`, contraintes de nom `tp.local` ; seule autorité qui signe les certificats finaux.
7. **Certificats finaux :** validité maximale de 90 jours, usage limité (serveur TLS ou client TLS), renouvelés avant expiration.
8. **Révocation :** à la demande du titulaire ou de l'administrateur dès qu'une compromission de clé est suspectée ou en fin d'usage, avec le motif consigné.
9. **Publication :** après chaque révocation, l'AC régénère et publie sa CRL aussitôt ; validité maximale d'une CRL : 30 jours.
10. **Traçabilité :** chaque émission et chaque révocation est enregistrée (base `index.txt`) ; l'AC ne conserve aucune clé privée de certificat final, et aucune clé privée n'est publiée dans un dépôt.
