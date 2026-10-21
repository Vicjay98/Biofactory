# Biofactory — Vision et point de reprise

Document établi le 21 octobre 2026 à partir de la conversation partagée
[« Conception jeu incrémental »](https://chatgpt.com/share/6ad89fdd-13e8-83ed-9f10-5283d32af759)
et du code au commit `311b3c96bc050f6fbff8ad2c843930d9048e1778`.

Les numéros de messages ci-dessous renvoient à l'archive extraite du lien partagé.
Ils permettent de retrouver les décisions dans leur contexte. Le lien contient
823 entrées, dont 183 messages utilisateur ; certaines entrées sont vides ou
masquées. Les images et les sorties d'outils masquées ne sont pas récupérables
dans le texte de la page. La conversation a évolué : une idée ancienne ne doit
pas annuler une correction plus récente.

## Mise à jour : premier squelette physiologique implémenté

La première étape du point de reprise ci-dessous est désormais développée :
états physiologiques, production réelle des usines organiques, entretien ATP,
apport d'O₂ par les membranes extérieures et diagnostics au survol. Une action
de secours absorbe un peu d'O₂ avec délai ; la spécialisation d'une membrane
paie le stock local et augmente effectivement les échanges. L'objectif est
de maintenir la cellule stable pendant 20 secondes.

La palette permanente est devenue une liste ouverte depuis Construction dans
le menu contextuel du cytoplasme. Le jeu continue pendant les menus. Les
conduits et le stockage non fonctionnels sont désactivés.

Le parcours d'une pénurie prolongée jusqu'à une stabilisation est vérifié dans
les tests du dépôt. Voir le [README](../README.md) pour les commandes, les
limites du prototype et les gestes de test. Les tableaux plus bas décrivent
toujours l'état de référence initial, avant ce développement.

La prochaine priorité de conception est d'essayer ce début jouable, de régler
les débits et de choisir comment introduire la collecte de nutriments. La
géométrie multicellulaire, les pompes, les dégâts et l'arbre technologique
complet restent des étapes ultérieures.

## Direction du jeu

Biofactory est un jeu de construction et d'automatisation biologique en vue du
dessus, avec une progression incrémentale. Le joueur conçoit un organisme dont
la forme, les cellules, les membranes et les circuits de ressources déterminent
réellement le fonctionnement.

L'objectif est de construire un organisme autonome et complexe : gérer énergie,
ressources, collecte, transport, spécialisation et, plus tard, défense et mouvement.
L'architecture doit être repensée à mesure que l'organisme évolue. Il ne suffit
pas d'acheter une amélioration universellement supérieure.

Le tout premier concept commençait avec un atome. La direction finale validée
pour le début jouable commence désormais avec une **cellule malade mais
récupérable**. Le développement immédiat doit suivre cette décision récente
(messages 812, 817, 818 et 823).

## Dernière décision et prochaine étape

Au message 818, l'utilisateur valide la proposition du message 817 :
« tu me régale. Partons la ddessus ».
Le message 823 fixe ensuite la première portion jouable :

1. Une cellule défaillante présente un problème simple et visible.
2. Le joueur observe et comprend pourquoi elle manque d'O₂ ou d'ATP.
3. Une collecte manuelle limitée permet un secours temporaire.
4. Une membrane spécialisée améliore puis automatise l'apport d'O₂.
5. Le métabolisme et la production d'ATP permettent de stabiliser la cellule.
6. La croissance augmente les besoins et fait apparaître une contrainte réelle.
7. La première cellule spécialisée devient une solution compréhensible.

La prochaine étape proposée à la fin de l'ancienne discussion est le squelette
du début de partie, dans cet ordre de travail :

- un état physiologique lisible de la cellule : stable, faible, critique, etc. ;
- une vraie consommation et production d'O₂ et d'ATP dans la cellule et ses
  structures organiques ;
- un diagnostic au survol qui explique les causes des problèmes ;
- ensuite, une absorption manuelle de secours et une amélioration automatique
  qui résolvent le problème présenté.

Les noms exacts d'états, les débits, les seuils et les durées restent à définir
et à équilibrer. Les exemples chiffrés de la conversation ne sont pas des
valeurs de conception imposées.

**Règle directrice : une nouvelle mécanique résout un problème que le joueur
a déjà rencontré.** Ne pas développer tous les systèmes futurs avant d'avoir
une première boucle de stabilisation intéressante.

## Expérience du début de partie

- Le premier objectif est de stabiliser la cellule, puis de la rendre autonome.
- L'urgence doit rester récupérable. Un déficit peut ralentir le fonctionnement
  ou mener à une dormance ; éviter une mort immédiate pendant que le joueur
  découvre les explications.
- La collecte manuelle sert de secours et ne doit pas devenir un clicker
  répétitif ou permettre de téléporter librement les ressources.
- Le joueur influence progressivement les flux grâce à son architecture.
- Le diagnostic doit montrer les causes : apport O₂ faible, production ATP
  insuffisante, entretien trop coûteux, etc.
- Introduire peu de notions à la fois. O₂, ATP, nutriments et intégrité sont les
  premiers concepts envisagés ; les autres ressources arrivent progressivement.
- Des dégâts visibles, des fuites ou un objectif de stabilité sont des pistes
  proposées, pas des systèmes déjà implémentés.

## Interface et interactions retenues

Les messages 777 à 789 remplacent l'ancienne palette permanente comme interface
cible. La palette actuelle reste un prototype à migrer, pas le résultat final.

- Le jeu continue en temps réel pendant les menus et les actions.
- Survoler sert à comprendre ; cliquer sert à agir.
- Clic droit sur le cytoplasme : petit menu contextuel avec Construction.
- La liste des constructions apparaît près de la cellule mais à l'extérieur
  pour laisser l'espace de placement libre. Blanc : constructible ; gris :
  ressources ou conditions manquantes. Elle suit l'état réel de la cellule.
- Survol d'une entrée de construction : coût, taille, besoins et prérequis.
- Survol d'une structure existante : état opérationnel, production,
  consommation, approvisionnement et alertes de cette instance.
- Clic droit sur une structure : actions dont le démontage avec restitution
  dans l'inventaire de la cellule propriétaire.
- Clic droit sur une membrane : Agrandir, Modifier, Créer une nouvelle cellule.
- Le joueur n'a pas à activer un mode de construction permanent. Des états
  d'interaction internes restent nécessaires pour interpréter les clics.

Le remboursement fondé sur le coût effectivement payé et un ratio réglable
de récupération a été proposé au message 782. Les détails d'équilibrage restent
à arrêter ; conserver l'intention utilisateur de récupération des ressources.

## Géométrie et croissance

La direction cible est organique : contours courbes, pas une grille de carrés
comme représentation finale. Les structures intérieures ont une empreinte et
doivent tenir dans la cellule sans se chevaucher, avec de futurs compromis
d'encombrement et d'efficacité.

La règle récente des messages 789 et 796 remplace les anciennes idées de
croissance simultanée de plusieurs cellules :

**Une action de croissance ou de modification porte sur une seule section
logique, d'un seul type de membrane, appartenant à une seule cellule.**

Une section est continue entre deux jonctions. Pour son agrandissement, utiliser
ses extrémités existantes comme ancrages est une proposition récente ; le choix
exact de l'interaction reste à implémenter. Ne pas réintroduire une sélection
traversant plusieurs cellules ou types sous prétexte que cela avait été discuté
plus tôt.

Pour une nouvelle cellule, le joueur doit pouvoir choisir un type de membrane
débloqué et voir une forme attachée à la cellule existante. L'aperçu suit la
souris et indique en vert ou rouge les conditions de validation : géométrie,
surface, collisions et ressources.

Lors d'un contact entre cellules, chacune conserve sa propre membrane et son
type. Une interface logique relie les deux portions de membrane. Elle ne
remplace pas les deux membranes par une membrane unique (message 801, qui
précise et remplace une proposition antérieure).

Une croissance peut créer plusieurs contacts et donc subdiviser la section
initiale en plusieurs sections et interfaces. Les cellules touchées ne doivent
pas être déformées ou facturées à nouveau simplement à cause du contact.

### Coûts et cas de l'organisme en U

Le cas d'une cellule grandissant à l'intérieur d'un U montre qu'un coût fondé
uniquement sur l'augmentation nette du périmètre est insuffisant : l'aire peut
augmenter énormément avec peu de périmètre supplémentaire.

Le modèle de conception accepté aux messages 797, 801 et 802 distingue :

- le cytoplasme ou la biomasse ajouté, selon l'aire gagnée ;
- la membrane réellement produite, selon son type ;
- les contacts ou jonctions créés ;
- le remodelage énergétique.

L'entretien doit également tenir compte du cytoplasme, des membranes, des
interfaces, des structures et du transport au fur et à mesure de leur ajout.
L'utilisateur souhaite qu'une très grande cellule devienne inefficace et que
la spécialisation multicellulaire ait un intérêt ; la courbe non linéaire et
ses paramètres restent à déterminer.

## Ressources, transport et performances

- Chaque cellule possède son inventaire. Construire dans B ne peut pas
  dépenser directement le stock de A : un transfert est nécessaire.
- `ResourceManager` sert de façade pour la cellule active, pas de réserve
  commune à tout l'organisme.
- Une ressource en transit devra être distinguée d'une ressource disponible.
- La diffusion passive dépend des différences de concentration, des
  perméabilités, de la longueur de contact et des résistances des interfaces.
- Une pompe active peut déplacer une ressource contre un gradient en payant
  de l'ATP. Le sens d'un flux ne vient pas d'une attraction gratuite imposée
  par le seul nom du type de membrane.
- Les conduits doivent garder leur intérêt : débit, distance et contrôle,
  contre coûts, place et vulnérabilité. Ils ne remplacent pas automatiquement
  tous les échanges membranaires.
- Les membranes extérieures et les échanges avec une cellule voisine pourront
  avoir des propriétés différentes. L'ancien `allowed_shared = false` de la
  membrane O₂ a explicitement été remis en question au message 807.
- Les quantités et les flux sont simulés numériquement ; les particules
  visibles ne représentent qu'une sélection lisible et limitée des ressources.
- Pas une particule physique par molécule ni une diffusion pixel par pixel.
- Les ressources C, H, N, P, S et les spécialisations futures font partie de la
  vision, mais ne doivent pas toutes encombrer l'introduction.

Le milieu initial envisagé est aquatique. Les variantes de milieu, les
déplacements, les défenses et les menaces sont des extensions futures.

## Intégrité et dégâts

L'utilisateur demande des points de vie pour les structures physiques. Un
système générique d'intégrité a été proposé : PV, dégâts, résistance,
réparation et destruction. Pour une membrane, les PV pourraient dépendre de
la longueur. Les dégâts doivent affecter le fonctionnement de façon lisible,
par exemple les échanges ou les fuites.

Le détail d'une intégrité globale dérivée des composants reste une proposition
à préciser. Ne pas multiplier les tâches répétitives de réparation sans
décision intéressante pour le joueur.

## État observé dans le code

Projet Godot : `biofactory/project.godot`, fonctionnalités déclarées Godot 4.7.
La scène principale est `biofactory/scene/main/game.tscn`.

| Élément | État au commit de référence |
| --- | --- |
| Catalogues | Ressources, recettes, bâtiments, membranes et configuration spatiale présents. |
| Ressources | 10 ressources dans le catalogue, dont ATP, O₂, nutriments, lipides, déchets et éléments chimiques. |
| Inventaires | `BioCell` instancie son propre inventaire ; la construction organique dépense ce stock local. |
| Cellule de départ | Une `StarterCell`, son contour, son contrôleur de croissance et sa sélection. |
| Géométrie | Contour organique, sections logiques, aperçu et croissance prototypés. |
| Bâtiments organiques | Placement, empreinte, chevauchements et déplacement présents. |
| ATP | Recette et `RecipeProcessor` présents. L'ancien `Building` sur grille exécute les recettes ; `OrganicBuilding` ne les exécute pas encore. |
| Membranes | Deux types : basique et échange O₂. Le survol montre une fiche ; le clic droit alterne directement le type dans le prototype. |
| Entretien | Le coût ATP/s des membranes est calculé dans `BioCell`, mais aucune boucle de consommation physiologique n'y est branchée. |
| Croissance économique | `MembraneGrowthEconomy` facture actuellement l'augmentation de longueur ; le coût de biomasse selon l'aire reste à ajouter. |
| Interface | Ancienne palette permanente et tableau de toutes les ressources encore présents. Les menus contextuels cibles ne sont pas encore réalisés. |
| Début jouable | Pas encore d'état physiologique, d'absorption manuelle ni de transport O₂ automatique effectif. |

Ne pas confondre un nom, une description ou une donnée de catalogue avec une
fonctionnalité simulée. Une membrane appelée « échange O₂ » n'absorbe pas encore
d'O₂ simplement parce qu'elle existe dans le catalogue.

Les vérifications de l'environnement ont validé l'import et le démarrage sans
affichage avec Godot 4.7.2, ainsi qu'un contrôle externe de 13 assertions,
notamment l'inventaire initial et l'exécution isolée de la recette ATP.
Ce n'est pas une validation du début de partie complet ou des interactions
visuelles. Aucun fichier de logique de jeu n'a été modifié pour cette synthèse.

## Reprise et méthode de travail

Repartir du squelette physiologique décidé au message 823. Réutiliser les
inventaires et les recettes existants, puis intégrer la simulation dans les
structures organiques. Rendre la cause des déficits lisible avant d'étendre
la géométrie multicellulaire ou le réseau de transport complet.

L'utilisateur souhaite un vrai jeu abouti et attend des retours francs sur les
idées. Il débute avec Godot et GitHub ; expliquer les changements et leurs tests
concrètement. Quand des gestes dans l'éditeur sont nécessaires, les décrire
pas à pas. Le développement cloud permet désormais d'éviter les anciens
problèmes de copier-coller et de mélange tabulations/espaces.

Mettre à jour ce document lorsque la direction change. Distinguer les décisions
validées, les propositions à tester et ce qui est réellement implémenté.
