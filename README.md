# Biofactory

Prototype Godot 4.7 d'un jeu d'automatisation biologique en vue du dessus.
L'organisme doit devenir autonome grâce à la géométrie de ses cellules, aux
membranes spécialisées et, à terme, au transport et à la spécialisation.

Le projet à importer dans Godot est **`biofactory/project.godot`**.
La scène principale est `biofactory/scene/main/game.tscn` ; lancer le projet
avec **F5**. Godot 4.7.2 est la version utilisée pour les vérifications cloud.

## Premier essai : stabiliser la cellule

1. La cellule commence affaiblie avec peu d'oxygène et d'ATP. L'usine ATP
   centrale fonctionne déjà ; elle consomme son inventaire local.
2. Survoler la cellule, son usine ou sa membrane pour voir le diagnostic.
3. Faire un clic droit sur le contour de la cellule :
   - **Absorber 2 O₂ (secours)** fournit une petite quantité d'oxygène dissous,
     avec quatre secondes de récupération entre deux actions ;
   - **Membrane d'échange d'oxygène** remplace la section ciblée en payant
     les lipides et le phosphore indiqués. Son apport d'O₂ est réel et automatique.
4. Chercher à maintenir la cellule **stable pendant 20 secondes**. Le compteur
   repart à zéro si elle redevient affaiblie. Le premier succès reste mémorisé
   pendant la partie.
5. Faire un clic droit dans le cytoplasme, puis choisir **Construction** pour
   ouvrir la liste près de la cellule. Choisir Usine ATP, puis placer avec le
   clic gauche ; clic droit pour annuler. Une structure nécessite la place et
   les ressources présentes dans cette cellule.

La caméra se déplace avec ZQSD et zoome avec la molette. La construction
contextuelle et ses listes ne mettent pas la simulation en pause.

Le survol sélectionne une portion de membrane continue du même type et du
même contact, jusqu'à ses vraies jonctions. Les points d'agrandissement ne
créent pas de nouvelles sections. Les anciens fragments techniques sont
sélectionnés ensemble, y compris à la fermeture du contour ; la longueur
affichée et le coût de spécialisation portent sur cette portion complète.

## Fonctionnement de cette première version

- Chaque usine ATP consomme 2 nutriments et 1 O₂ pour produire 5 ATP et 1 déchet
  par cycle de deux secondes à vitesse normale.
- Le manque d'O₂ ou d'ATP ralentit le métabolisme à 65 %. Il ne le coupe pas
  entièrement, afin qu'une cellule puisse se rétablir après une pénurie.
- L'entretien ATP dépend de la surface du cytoplasme et des sections membranaires.
- L'O₂ entrant dépend de la longueur et de la perméabilité des sections
  extérieures, ainsi que de la différence de concentration avec l'environnement.
- Les états sont Stable, Affaiblie, Critique et Dormance. Ils n'entraînent pas
  de destruction immédiate de la cellule.
- Les valeurs de départ et les seuils sont réglables dans
  `biofactory/data/spatial/starter_physiology.tres` via l'Inspecteur de Godot.

L'environnement est pour l'instant un réservoir uniforme d'O₂ dissous, sans
particules interactives. La collecte manuelle est une action sur la membrane.
Le stock initial de nutriments est fini ; sa collecte automatique reste à
développer. Le stockage et les conduits sont affichés désactivés puisqu'ils ne
simulent pas encore ces fonctions. Les PV, la sauvegarde des parties, le réseau
multicellulaire et la nouvelle géométrie de croissance restent à développer.

Voir [le contexte de conception](docs/CONTEXTE_PROJET.md) pour les décisions et
la distinction entre ce prototype et la vision complète.

## Vérifications automatiques

Depuis la racine du dépôt, avec Godot 4.7 dans le PATH :

```bash
godot --headless --path biofactory --import
godot --headless --path biofactory --script res://tests/test_physiology.gd
godot --headless --path biofactory --script res://tests/test_membrane_selection.gd
godot --headless --path biofactory --fixed-fps 60 --quit-after 600
```

Le deuxième lancement doit annoncer `BIOFACTORY_TESTS: 48 checks, 0 failures`
et terminer avec un code de sortie nul, sans `SCRIPT ERROR` ni `ERROR`.
Il vérifie notamment la consommation réelle, la conservation des recettes,
la récupération après une pénurie, les inventaires locaux, les coûts et
conditions des actions, l'entretien après croissance et les diagnostics.

La suite des membranes doit annoncer
`BIOFACTORY_MEMBRANE_TESTS: 51 checks, 0 failures`. Elle couvre les agrandissements
confirmés ou annulés, les portions traversant la fermeture du contour, les
vraies jonctions, les types et cellules voisines différents, le surlignage et
la cohérence des longueurs et des coûts.

Les interactions de survol, les menus contextuels et la stabilisation après
une action de spécialisation ont aussi été vérifiés dans Godot avec affichage
logiciel sous Linux. Un essai sur le PC du joueur reste utile pour valider le
confort des commandes et l'équilibrage.
