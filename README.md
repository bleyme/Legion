# Légion

Arène de combat 2D nerveuse façon Soldat / Mini Militia, faite avec **Godot 4.4**.
Jetpacks, rocket-jumps, neuf armes, des bots coriaces et jusqu'à six combattants
en local (clavier, souris, manettes).

## Lancer le jeu

1. Installer [Godot 4.4](https://godotengine.org/download) (version standard).
2. Ouvrir le dossier du projet dans Godot, puis **F5**.
   En ligne de commande : `godot --path .`

## Modes

- **Chacun pour soi** : le premier à atteindre la limite de frags gagne.
- **Équipes** (rouge contre bleue) : pas de tir ami, les balles traversent les alliés.
  Parfait pour jouer à deux en coopération contre des bots.
- **Survie** (solo ou coop) : des vagues de bots de plus en plus nombreux et
  précis, une vague d'élite toutes les 5. Trois vies chacun, une vie bonus toutes
  les 3 vagues, soins complets entre les vagues. Le record de vague est
  sauvegardé pour chaque arène. Les armes de la carte sont réservées aux héros.
  Toutes les 5 vagues, un **boss** aux attaques lisibles mais brutales :
  **le Mastodonte** (minigun, quasi inébranlable, onde de choc au corps à corps),
  **le Spectre** (sniper qui se téléporte ; son laser vous laisse le temps
  d'esquiver), **la Reine des Moutons** (troupeaux kamikazes et saintes
  grenades). Le vaincre rend une vie à chacun.

Chaque emplacement de joueur (six au maximum) peut être : clavier + souris,
clavier seul (flèches), manette 1 à 4, ou un bot de niveau **Recrue**, **Soldat**,
**Vétéran** ou **Légion**. Les réglages sont mémorisés entre les parties.

## Arènes

**Tout se détruit** (façon Worms) : chaque explosion creuse un cratère dans les
blocs, les toits de bunker et la croûte du sol ; seuls les murs extérieurs et
le socle rocheux tiennent. Les soldats escaladent les petits rebords des
cratères. Une arène ne ressemble jamais deux fois à la même.

| Arène | Taille | Style |
|---|---|---|
| Avant-poste | grande | symétrique, bunkers, passerelles, roquettes au sommet |
| Fonderie | haute | quatre étages, combats serrés, minigun sur le four central |
| Duel | petite | pour les 1 contre 1 |

## Commandes

Les touches sont physiques : sur un clavier AZERTY, « WASD » correspond à **ZQSD**.

| Action | Clavier + souris | Clavier (flèches) | Manette |
|---|---|---|---|
| Se déplacer | Z Q S D | ← → | stick gauche |
| Sauter / jetpack (maintenir en l'air) | Z ou Espace | ↑ | A |
| S'accroupir / traverser une passerelle (+ saut) | S | ↓ | stick gauche ↓ |
| Viser | souris | automatique | stick droit (aide à la visée) |
| Tirer | clic gauche | Entrée, Ctrl droit, Pavé 0 | RT / R1 |
| Grenade | clic droit ou G | Maj droit, Pavé 1 | LT / L1 |
| Recharger | R | Retour arrière, Pavé 3 | X |
| Changer d'arme / ramasser au sol | A ou E | Pavé 2, « . » | Y |
| Corde ninja (maintenir ; saut = remonter, bas = descendre) | F, Maj gauche, bouton souris 4 | Pavé 4, « / », Fin | LB / L1 |
| Pause | Échap ou P | Échap ou P | Start |
| Plein écran | F11 | F11 | — |

## Mouvements avancés

Faciles à prendre en main, longs à maîtriser :

- **Corde ninja** : on s'accroche partout, on se balance, on la lâche au sommet
  pour être projeté (« Fronde ! »). Elle se combine avec le jetpack.
- **Saut mural** : sauter en touchant un mur rebondit dessus.
- **Glissade** : s'accroupir en pleine course donne un coup de vitesse ; sauter
  pendant la glissade garde l'élan.
- **Élan conservé** : la vitesse d'une explosion, d'une corde ou d'une glissade
  ne retombe que lentement au sol.
- **Envol parfait** : sauter juste au moment où une explosion vous touche
  vous propulse 40 % plus loin.

## Armes

Tout le monde réapparaît avec un **pistolet** (munitions infinies) et deux grenades.
Les armes principales se ramassent sur la carte ; celles des joueurs tués restent au sol.

| Arme | Rôle |
|---|---|
| Mitraillette | cadence très élevée, dispersion large |
| Fusil d'assaut | polyvalent et précis |
| Fusil à pompe | dévastateur à bout portant, recul qui propulse |
| Sniper | tir instantané, ×2 à la tête, viseur laser |
| Railgun | rayon instantané qui traverse les ennemis |
| Minigun | déluge de balles, ralentit le porteur |
| Lance-roquettes | explosion de zone, rocket-jump |
| Lance-grenades | projectiles rebondissants, explosent au contact |

Et l'arsenal absurde, rare et redoutable :

| Arme | Rôle |
|---|---|
| Mouton kamikaze | trotte vers l'ennemi, saute les obstacles, explose au contact |
| Banane à fragmentation | explose en six mini-bananes explosives |
| Sainte grenade | chœur céleste, puis rayon d'explosion énorme |
| Frappe aérienne | une balise, puis six missiles tombent du ciel |

Les explosions démembrent, les autres morts envoient le corps en ragdoll.

**Arsenal** : en plus du mode complet, des parties à arme unique — Roquettes,
Railgun instagib (un tir = un frag), Fusils à pompe ou Snipers.

Tirs à la tête, dégâts dégressifs à distance, recul, projection par les
explosions (le souffle est bloqué par les murs) et bouclier de réapparition
qui disparaît dès qu'on tire.

## Sous le capot

- `scripts/game.gd` : réglages de partie, touches, équipes, sauvegarde (`user://legion.cfg`).
- `scripts/weapon_data.gd` : toutes les armes dans un seul tableau à équilibrer.
- `scripts/maps.gd` : les arènes décrites par des rectangles (blocs, passerelles, spawns, objets).
- `scenes/map/arena.gd` : terrain destructible — une image dont l'alpha fait la
  matière, affichée par tuiles de 128 px et convertie en polygones de collision
  par tuiles de 64 px ; un cratère ne reconstruit que les tuiles touchées (2 à 7 ms).
- `scenes/player/` : le soldat (mouvement, armes, dégâts) et ses contrôleurs
  (clavier/souris, clavier seul, manette, bot).
- `scenes/weapons/projectiles.gd` : chaque projectile balaie un rayon entre deux
  frames, donc même les balles de sniper ne traversent jamais une plateforme.
- `scenes/fx/fx.gd` : toutes les particules dans des tableaux compacts, dessinées
  en deux passes (normale + additive) au lieu d'un nœud par étincelle.
- `scripts/music.gd` : bande-son (menu et combat) composée et synthétisée au
  démarrage sur un thread séparé, avec fondu enchaîné.
- `scripts/sound_manager.gd` : sons synthétisés au démarrage, joués via un
  ensemble fixe de voix spatialisées (aucune allocation pendant le jeu).
- `scenes/main/` : règles du match, caméra partagée, HUD, pause et fin de partie.
