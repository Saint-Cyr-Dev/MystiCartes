# MystiCartes V2 — Catalogue du set de lancement

Statut : **proposition de conception à valider** avant migration Supabase ou implémentation du moteur.

Référence de règles : GDD officiel V2 v1.1 verrouillé.

## Structure du set

- 150 cartes distinctes.
- 15 cartes pour chacune des 10 familles principales.
- Distribution par famille : 7 Personnages, 3 Actions, 2 Pièges, 1 Terrain, 1 Relique et 1 Mythique.
- Distribution totale : 70 Personnages, 30 Actions, 20 Pièges, 10 Terrains, 10 Reliques et 10 Mythiques.
- Toutes les Mythiques sont de rang 9 ou 10 et disposent d'une condition d'invocation explicite.
- Les valeurs ATK/DEF et les effets constituent une base d'alpha-test, pas un équilibrage final.

## Conventions de données

- Catégories canoniques : `personnage`, `action`, `piège`, `terrain`, `relique`, `mythique`.
- Sous-types Action : `normal`, `quick`, `continuous`, `equipment`.
- Sous-types Piège : `normal`, `continuous`, `counter`.
- Modes de Relique : `action`, `equipment`, `alternative_win`.
- Raretés : `commune`, `rare`, `épique`, `légendaire`.
- « Annule l'activation » signifie que la carte annulée ne se résout pas. Si elle se trouvait sur le terrain, elle est ensuite détruite sauf indication contraire.
- « Une fois par tour » est suivi séparément pour chaque exemplaire face visible de la carte.
- Une durée « ce tour » expire pendant la Phase de Fin.

## Famille Babi

Identité de jeu : tempo urbain, Actions rapides, mobilité des positions et pression sur les zones adverses.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| BAB-001 | Apprenti du Gbaka | Personnage | Commune | 2 · 900/1200 | Vent | — | À son invocation : tu peux piocher 1 carte, puis défausse 1 carte. |
| BAB-002 | Messagère Wôrô-Wôrô | Personnage | Commune | 3 · 1400/1000 | Vent | Maquis | À son invocation : tu peux changer la position de combat d'un autre Personnage que tu contrôles. |
| BAB-003 | Gardien du Carrefour | Personnage simple | Commune | 4 · 1800/1700 | Terre | — | Aucun effet. |
| BAB-004 | Danseuse des Néons | Personnage | Rare | 4 · 1700/1500 | Lumière | Maquis | Une fois par tour, après l'activation d'une Action rapide : cette carte gagne 300 ATK jusqu'à la fin du tour. |
| BAB-005 | Hacker du Marché | Personnage | Rare | 5 · 2100/1800 | Ombre | — | À son invocation : cible 1 carte posée dans une Zone Action/Piège adverse ; regarde-la. Tu peux la renvoyer dans la main de son propriétaire. |
| BAB-006 | Champion du Bitume | Personnage | Épique | 6 · 2400/2000 | Feu | Savane | Une fois par tour, si cette carte détruit un Personnage au combat : pioche 1 carte, puis défausse 1 carte. |
| BAB-007 | Reine du Plateau | Personnage | Épique | 7 · 2700/2500 | Lumière | Royaume | Une fois par tour : tu peux renvoyer 1 autre carte Babi que tu contrôles dans ta main ; cette carte peut attaquer directement ce tour, mais les dégâts de cette attaque sont divisés par deux, arrondis au supérieur. |
| BAB-008 | Trajet Express | Action `quick` | Commune | — | Vent | — | Cible 1 Personnage Babi que tu contrôles ; change sa position de combat. S'il passe en Attaque, il gagne 300 ATK ce tour. |
| BAB-009 | Réseau Saturé | Action `normal` | Rare | — | Ombre | — | Cible 1 carte posée dans une Zone Action/Piège adverse ; renvoie-la dans la main de son propriétaire. |
| BAB-010 | Battement de la Ville | Action `normal` | Épique | — | Lumière | Ancêtre | Invocation Fusion : envoie depuis ton terrain au Cimetière « Messagère Wôrô-Wôrô » et « Champion du Bitume » ; invoque spécialement « Génie d'Abidjan, Cœur Électrique » depuis ta Réserve des Mythiques. |
| BAB-011 | Feu Rouge Mystique | Piège `normal` | Commune | — | Feu | — | Lorsqu'un Personnage adverse déclare une attaque : annule cette attaque, puis passe l'attaquant en Défense s'il peut changer de position. |
| BAB-012 | Coupure de Courant | Piège `counter` | Rare | — | Ombre | — | Lorsqu'une Action est activée : défausse 1 carte ; annule l'activation et détruis cette Action. |
| BAB-013 | Abidjan Minuit | Terrain | Rare | — | Lumière | Maquis | Tous les Personnages Babi gagnent 200 ATK/DEF. La première Action rapide que tu actives pendant chaque tour ne peut pas être annulée par une Vitesse 2. |
| BAB-014 | Smartphone des Ancêtres | Relique `equipment` | Épique | — | Esprit | Ancêtre | Équipe uniquement un Personnage Babi. Une fois par tour : regarde la carte du dessus de ton deck ; laisse-la au-dessus ou place-la sous le deck. |
| BAB-015 | Génie d'Abidjan, Cœur Électrique | Mythique · Fusion | Légendaire | 9 · 3200/2800 | Lumière | Ancêtre | Doit d'abord être invoqué par « Battement de la Ville ». À son invocation : renvoie jusqu'à 2 cartes posées adverses dans la main de leur propriétaire. Une fois par tour, lorsqu'une Action rapide est activée : cette carte gagne 500 ATK jusqu'à la fin du tour. |

## Famille Royaume

Identité de jeu : sacrifices valorisés, discipline de terrain, protection et Personnages de haut rang.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| ROY-001 | Page aux Bracelets d'Or | Personnage | Commune | 1 · 400/1000 | Lumière | Village | Si cette carte est sacrifiée pour l'invocation d'un Personnage Royaume : pioche 1 carte. |
| ROY-002 | Lancière de la Porte Rouge | Personnage simple | Commune | 3 · 1500/1200 | Feu | — | Aucun effet. |
| ROY-003 | Garde du Tambour Royal | Personnage | Commune | 4 · 1700/2000 | Terre | Village | Les autres Personnages Royaume que tu contrôles ne peuvent pas être ciblés par une attaque tant que cette carte est en position d'Attaque. |
| ROY-004 | Stratège des Sept Cours | Personnage | Rare | 4 · 1600/1800 | Esprit | — | À son invocation : regarde les 3 cartes du dessus de ton deck ; ajoute 1 carte Royaume parmi elles à ta main et replace les autres sous le deck dans l'ordre de ton choix. |
| ROY-005 | Cavalier au Manteau Pourpre | Personnage | Rare | 5 · 2200/1700 | Vent | Savane | Si un Personnage a été sacrifié pour son invocation, cette carte gagne 400 ATK pendant le tour de son invocation. |
| ROY-006 | Reine des Remparts Solaires | Personnage | Épique | 6 · 2300/2600 | Lumière | — | Une fois par tour, lorsqu'une carte Royaume que tu contrôles devrait être détruite par un effet : tu peux défausser 1 carte ; elle n'est pas détruite. |
| ROY-007 | Roi au Serment de Fer | Personnage | Épique | 8 · 3000/2700 | Terre | Ancêtre | À son invocation par sacrifice : cible jusqu'à 2 Personnages Royaume dans ton Cimetière de rang 4 ou moins ; invoque-les spécialement en Défense, effets annulés ce tour. |
| ROY-008 | Décret de Mobilisation | Action `normal` | Commune | — | Lumière | — | Ajoute à ta main 1 Personnage Royaume de rang 4 ou moins depuis ton deck. |
| ROY-009 | Relève de la Garde | Action `quick` | Rare | — | Terre | — | Lorsqu'un Personnage Royaume devrait être détruit : sacrifie 1 autre Personnage que tu contrôles ; empêche cette destruction. |
| ROY-010 | Couronnement des Sept Tambours | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation ancestrale : sacrifie des Personnages que tu contrôles dont le total des rangs est au moins 9 ; invoque spécialement « Souverain des Sept Tambours » depuis ta Réserve des Mythiques. |
| ROY-011 | Herse de Lumière | Piège `normal` | Commune | — | Lumière | — | Lorsqu'un Personnage adverse déclare une attaque : cible cet attaquant ; il perd 800 ATK ce tour. S'il passe sous l'ATK de sa cible, annule l'attaque. |
| ROY-012 | Sceau Inviolable | Piège `counter` | Rare | — | Esprit | Ancêtre | Lorsqu'un effet cible une carte Royaume que tu contrôles : annule l'activation et détruis la carte ayant activé cet effet. |
| ROY-013 | Cour des Mille Étendards | Terrain | Rare | — | Terre | Village | Les Personnages Royaume gagnent 200 DEF. Chaque fois que tu sacrifies un Personnage, place 1 marqueur Serment ici. À 3 marqueurs ou plus, tes Personnages Royaume gagnent aussi 300 ATK. |
| ROY-014 | Couronne du Pacte Ancien | Relique `equipment` | Épique | — | Esprit | Ancêtre | Équipe un Personnage Royaume de rang 5 ou plus. Il gagne 400 ATK/DEF. S'il quitte le terrain, ajoute cette Relique à ta main au lieu de l'envoyer au Cimetière. |
| ROY-015 | Souverain des Sept Tambours | Mythique · Ancestrale | Légendaire | 10 · 3700/3400 | Esprit | Ancêtre | Doit d'abord être invoqué par « Couronnement des Sept Tambours ». À son invocation : jusqu'à 2 Personnages Royaume dans ton Cimetière reviennent spécialement en Défense. Une fois par tour : sacrifie 1 autre Personnage ; annule l'activation d'un effet de Vitesse 2 et détruis sa carte. |

## Famille Ancêtre

Identité de jeu : mémoire du Cimetière, effets déclenchés lors des départs du terrain et invocations ancestrales.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| ANC-001 | Porteur de Cauris | Personnage | Commune | 1 · 300/900 | Esprit | Village | Si cette carte est envoyée du terrain au Cimetière : place la carte du dessus de ton deck au Cimetière. |
| ANC-002 | Enfant des Songes Clairs | Personnage | Commune | 2 · 800/1300 | Lumière | Village | À son invocation : cible 1 carte Ancêtre dans ton Cimetière ; place-la sous ton deck. |
| ANC-003 | Veilleuse du Foyer Invisible | Personnage simple | Commune | 3 · 1300/1700 | Feu | Village | Aucun effet. |
| ANC-004 | Messager de la Première Pluie | Personnage | Rare | 4 · 1700/1600 | Eau | Lagune | À son invocation : envoie 1 carte Ancêtre depuis ton deck au Cimetière, sauf « Messager de la Première Pluie ». |
| ANC-005 | Gardienne des Noms Oubliés | Personnage | Rare | 5 · 2100/2200 | Esprit | Royaume | Une fois par tour : cible 1 Personnage de rang 4 ou moins dans ton Cimetière ; mélange cette carte dans le deck et ajoute la cible à ta main. |
| ANC-006 | Conseiller de l'Au-Delà | Personnage | Épique | 6 · 2300/2500 | Ombre | Royaume | Si cette carte est envoyée au Cimetière comme sacrifice ou coût : tu peux invoquer spécialement 1 Personnage Ancêtre de rang 3 ou moins depuis ton Cimetière. |
| ANC-007 | Matriarche aux Cent Mémoires | Personnage | Épique | 8 · 2900/3100 | Esprit | Village | À son invocation : cible jusqu'à 3 cartes Ancêtre dans ton Cimetière ; mélange-les dans le deck, puis pioche 1 carte. Cette carte gagne 100 ATK pour chaque carte ainsi mélangée. |
| ANC-008 | Parole Transmise | Action `normal` | Commune | — | Esprit | Village | Ajoute à ta main 1 carte Ancêtre depuis ton Cimetière, puis défausse 1 carte. |
| ANC-009 | Main des Aïeux | Action `quick` | Rare | — | Lumière | — | Cible 1 Personnage Ancêtre que tu contrôles et 1 Personnage adverse ; le premier gagne 600 ATK/DEF et le second perd 300 ATK/DEF ce tour. |
| ANC-010 | Appel des Huit Veillées | Action `normal` | Épique | — | Esprit | — | Invocation ancestrale : bannis depuis ton Cimetière des Personnages Ancêtre dont le total des rangs est au moins 10 ; invoque spécialement « Mère des Premières Lueurs » depuis ta Réserve des Mythiques. |
| ANC-011 | Conseil des Invisibles | Piège `normal` | Commune | — | Esprit | — | Lorsqu'un Personnage que tu contrôles est détruit : invoque spécialement 1 Personnage Ancêtre de rang inférieur depuis ton Cimetière en Défense. |
| ANC-012 | Refus de l'Oubli | Piège `counter` | Rare | — | Lumière | Royaume | Lorsqu'une carte de ton Cimetière devrait être bannie par un effet adverse : annule l'activation et détruis sa carte. |
| ANC-013 | Bosquet des Voix Anciennes | Terrain | Rare | — | Nature | Forêt | Une fois par tour, lorsqu'une carte est envoyée de ton terrain au Cimetière : place 1 marqueur Mémoire ici. Retire 3 marqueurs ; pioche 1 carte, puis défausse 1 carte. |
| ANC-014 | Calebasse des Huit Noms | Relique `alternative_win` | Légendaire | — | Esprit | Village | Active cette Relique face visible dans une Zone Action/Piège libre. Chaque fois qu'un Personnage Ancêtre de nom différent est envoyé depuis ton terrain au Cimetière, place 1 marqueur Nom ici. Au début de ta Phase de Préparation, si cette carte possède 8 marqueurs Nom, tu remportes le duel. |
| ANC-015 | Mère des Premières Lueurs | Mythique · Ancestrale | Légendaire | 10 · 3500/3800 | Lumière | Village | Doit d'abord être invoquée par « Appel des Huit Veillées ». À son invocation : mélange jusqu'à 5 cartes de ton Cimetière dans le deck, puis gagne 300 PV par carte mélangée. Une fois par tour, si une carte Ancêtre quitte ton terrain : pioche 1 carte. |

## Famille Masque

Identité de jeu : poses face cachée, effets de retournement, changements de position et information trompeuse.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| MAS-001 | Porte-Masque Novice | Personnage · retournement | Commune | 2 · 700/1400 | Esprit | Village | Retournement : pioche 1 carte, puis défausse 1 carte. |
| MAS-002 | Danseur aux Pas Croisés | Personnage | Commune | 3 · 1400/1300 | Vent | Babi | Une fois par tour : change la position de combat de cette carte. Si elle passe en Défense, elle gagne 300 DEF ce tour. |
| MAS-003 | Sentinelle au Visage de Bois | Personnage simple | Commune | 4 · 1600/2100 | Nature | Forêt | Aucun effet. |
| MAS-004 | Rieuse aux Deux Visages | Personnage · retournement | Rare | 4 · 1700/1700 | Ombre | Maquis | Retournement : cible 1 Personnage face visible adverse ; son ATK et sa DEF sont échangées jusqu'à la fin du tour. |
| MAS-005 | Sculpteur des Gestes Secrets | Personnage | Rare | 5 · 2100/2300 | Terre | Village | À son invocation : tu peux poser face cachée 1 Personnage Masque de rang 4 ou moins depuis ta main dans une Zone Personnage libre. Cette pose ne consomme pas ta Pose normale. |
| MAS-006 | Masque Dan, Gardien des Seuils | Personnage | Épique | 6 · 2400/2500 | Esprit | Ancêtre | Les Personnages face cachée que tu contrôles ne peuvent pas être ciblés par des effets adverses. Une fois par tour : retourne face cachée en Défense 1 autre Personnage Masque face visible que tu contrôles. |
| MAS-007 | Maîtresse du Ballet Invisible | Personnage | Épique | 7 · 2700/2800 | Vent | Ancêtre | Une fois par tour : cible 1 Personnage sur le terrain ; passe-le en Défense face visible. Si c'était un Personnage Masque que tu contrôles, tu peux ensuite le retourner face cachée. |
| MAS-008 | Changement de Visage | Action `quick` | Commune | — | Ombre | — | Cible 1 Personnage Masque que tu contrôles ; retourne-le face cachée en Défense ou face visible dans sa position actuelle. |
| MAS-009 | Danse de Révélation | Action `normal` | Rare | — | Lumière | — | Retourne face visible jusqu'à 2 Personnages face cachée sur le terrain. Les effets de retournement des Personnages Masque que tu contrôles ainsi révélés peuvent s'activer. |
| MAS-010 | Rythme des Mille Visages | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation Fusion : envoie depuis ton terrain au Cimetière « Rieuse aux Deux Visages » et « Masque Dan, Gardien des Seuils » ; invoque spécialement « Masque du Premier Rythme » depuis ta Réserve des Mythiques. |
| MAS-011 | Faux Mouvement | Piège `normal` | Commune | — | Vent | — | Lorsqu'un Personnage adverse cible un Personnage face cachée pour une attaque : change la cible vers un autre Personnage que tu contrôles, si possible. |
| MAS-012 | Visage Interdit | Piège `counter` | Rare | — | Ombre | Dozo | Lorsqu'un effet adverse doit révéler ou retourner face visible une de tes cartes face cachée : annule l'activation et détruis sa carte. |
| MAS-013 | Place des Danses Secrètes | Terrain | Rare | — | Esprit | Village | Les Personnages Masque gagnent 200 DEF. La première fois par tour qu'un Personnage est retourné face visible, son contrôleur gagne 300 PV. |
| MAS-014 | Ciseau du Maître Sculpteur | Relique `equipment` | Épique | — | Terre | Village | Équipe un Personnage Masque. Il gagne 300 ATK/DEF. Une fois par tour, s'il a été retourné face visible ce tour : tu peux poser 1 Piège depuis ta main. |
| MAS-015 | Masque du Premier Rythme | Mythique · Fusion | Légendaire | 9 · 3100/3300 | Esprit | Ancêtre | Doit d'abord être invoqué par « Rythme des Mille Visages ». À son invocation : retourne face cachée en Défense jusqu'à 2 Personnages adverses. Une fois par tour, lorsqu'une carte est retournée face visible : annule ses effets jusqu'à la fin du tour ou fais gagner 500 ATK à cette carte ce tour. |

## Famille Dozo

Identité de jeu : chasse méthodique, Pièges, marquage d'une proie et bannissement ciblé.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| DOZ-001 | Apprenti Pisteur | Personnage | Commune | 1 · 500/800 | Nature | Forêt | À son invocation : regarde la carte du dessus du deck adverse et replace-la au-dessus. |
| DOZ-002 | Archère des Hautes Herbes | Personnage | Commune | 3 · 1500/1000 | Vent | Savane | Si elle attaque un Personnage en Défense, elle gagne 300 ATK pendant le calcul des dégâts uniquement. |
| DOZ-003 | Gardien au Fusil Rituel | Personnage simple | Commune | 4 · 1800/1800 | Feu | Savane | Aucun effet. |
| DOZ-004 | Lecteur de Traces | Personnage | Rare | 4 · 1600/1900 | Terre | Forêt | À son invocation : ajoute à ta main 1 Piège Dozo depuis ton deck, puis place 1 carte de ta main sous ton deck. |
| DOZ-005 | Chasseuse au Manteau Brun | Personnage | Rare | 5 · 2200/1900 | Nature | Savane | Une fois par tour : cible 1 Personnage adverse face visible ; place 1 marqueur Proie sur lui. Cette carte gagne 300 ATK lorsqu'elle combat un Personnage avec un marqueur Proie. |
| DOZ-006 | Maître des Collets | Personnage | Épique | 6 · 2300/2600 | Terre | Forêt | Tu peux activer les Pièges Dozo le tour où ils sont posés, mais seulement pendant ton propre tour. Une seule fois par tour. |
| DOZ-007 | Capitaine de la Chasse Nocturne | Personnage | Épique | 8 · 3000/2800 | Ombre | Savane | À son invocation : place 1 marqueur Proie sur chaque Personnage adverse face visible. Une fois par tour, après la destruction au combat d'une Proie : bannis cette Proie au lieu de l'envoyer au Cimetière. |
| DOZ-008 | Piste Fraîche | Action `normal` | Commune | — | Terre | — | Cible 1 Personnage adverse face visible ; place 1 marqueur Proie sur lui, puis ajoute à ta main 1 Personnage Dozo de rang 4 ou moins depuis ton deck. |
| DOZ-009 | Tir de Sommation | Action `quick` | Rare | — | Feu | — | Cible 1 Personnage avec un marqueur Proie ; il perd 700 ATK ce tour. S'il est en Défense, il perd aussi 700 DEF ce tour. |
| DOZ-010 | Serment de la Lune des Chasseurs | Action `normal` | Épique | — | Ombre | Ancêtre | Invocation ancestrale : sacrifie 1 Personnage Dozo de rang 6 ou plus et bannis 2 Pièges depuis ton Cimetière ; invoque spécialement « Maître Dozo de la Lune Noire » depuis ta Réserve des Mythiques. |
| DOZ-011 | Collet des Hautes Herbes | Piège `normal` | Commune | — | Nature | Savane | Lorsqu'un Personnage adverse déclare une attaque : cible l'attaquant ; annule l'attaque, passe-le en Défense et place 1 marqueur Proie sur lui. |
| DOZ-012 | Dernier Coup de Sifflet | Piège `counter` | Rare | — | Vent | — | Lorsqu'un effet d'un Personnage avec un marqueur Proie est activé : annule l'activation et bannis ce Personnage. |
| DOZ-013 | Campement sous la Lune | Terrain | Rare | — | Ombre | Savane | Les Personnages Dozo gagnent 200 ATK/DEF. Une fois par tour, lorsqu'un Piège est activé : place 1 marqueur Proie sur 1 Personnage adverse face visible. |
| DOZ-014 | Corne du Premier Buffle | Relique `equipment` | Épique | — | Terre | Savane | Équipe un Personnage Dozo. Il gagne 400 ATK. Lorsqu'il détruit une Proie au combat : tu peux poser 1 Piège Dozo directement depuis ta main. |
| DOZ-015 | Maître Dozo de la Lune Noire | Mythique · Ancestrale | Légendaire | 10 · 3600/3500 | Ombre | Ancêtre | Doit d'abord être invoqué par « Serment de la Lune des Chasseurs ». Les Personnages adverses avec un marqueur Proie ne peuvent pas cibler d'autres cartes que celle-ci avec leurs attaques. Une fois par tour : bannis 1 Proie face visible, mais cette carte ne peut pas attaquer ce tour. |

## Famille Forêt

Identité de jeu : croissance progressive, Jetons Sylve, marqueurs Graine et récupération de PV.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| FOR-001 | Graine Qui Marche | Personnage | Commune | 1 · 300/600 | Nature | — | Si cette carte est envoyée du terrain au Cimetière : crée 1 Jeton Sylve en Défense (Nature, rang 1, 500 ATK/500 DEF). |
| FOR-002 | Singe aux Fruits d'Or | Personnage | Commune | 2 · 1000/900 | Nature | Savane | Une fois par tour, si tu gagnes des PV : cette carte gagne 300 ATK jusqu'à la fin du tour. |
| FOR-003 | Antilope des Sous-Bois | Personnage simple | Commune | 3 · 1500/1400 | Vent | Savane | Aucun effet. |
| FOR-004 | Guérisseuse des Lianes | Personnage | Rare | 4 · 1500/2000 | Nature | Village | À son invocation : gagne 500 PV. Une fois par tour, lorsqu'un Jeton est créé sur ton terrain : gagne 200 PV. |
| FOR-005 | Panthère des Racines | Personnage | Rare | 5 · 2200/1800 | Ombre | Savane | Cette carte peut attaquer directement si tu contrôles un Jeton Sylve, mais les dégâts de cette attaque sont divisés par deux, arrondis au supérieur. |
| FOR-006 | Gardien Iroko | Personnage | Épique | 6 · 2300/2800 | Terre | Ancêtre | Une fois par tour : sacrifie 1 Jeton ; empêche la destruction d'une carte Forêt que tu contrôles. |
| FOR-007 | Éléphante aux Jardins Vivants | Personnage | Épique | 8 · 2900/3200 | Nature | Savane | À son invocation : crée jusqu'à 2 Jetons Sylve en Défense. Les Jetons que tu contrôles gagnent 300 DEF. |
| FOR-008 | Germination Soudaine | Action `quick` | Commune | — | Nature | — | Crée 1 Jeton Sylve en Défense. Il ne peut pas être sacrifié pendant ce tour. |
| FOR-009 | Saison des Grandes Pluies | Action `continuous` | Rare | — | Eau | Lagune | À chaque Phase de Préparation de ton tour : place 1 marqueur Graine ici. Retire 2 marqueurs ; crée 1 Jeton Sylve ou gagne 500 PV. |
| FOR-010 | Racines du Cœur-Monde | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation Fusion : envoie depuis ton terrain au Cimetière « Gardien Iroko » et 2 Jetons Sylve ; invoque spécialement « Iroko, Cœur du Monde » depuis ta Réserve des Mythiques. |
| FOR-011 | Liane Entravante | Piège `normal` | Commune | — | Nature | — | Lorsqu'un Personnage adverse déclare une attaque : cible l'attaquant ; annule l'attaque et il ne peut pas changer de position pendant son prochain tour. |
| FOR-012 | Reprise Sauvage | Piège `continuous` | Rare | — | Nature | Ancêtre | Une fois par tour, lorsqu'un Personnage Forêt que tu contrôles est détruit : crée 1 Jeton Sylve en Défense. |
| FOR-013 | Forêt aux Mille Souffles | Terrain | Rare | — | Nature | Ancêtre | Les Personnages Forêt gagnent 200 ATK/DEF. Les Jetons Sylve gagnent 300 ATK/DEF supplémentaires. |
| FOR-014 | Graine de l'Arbre Originel | Relique `action` | Épique | — | Esprit | Ancêtre | Place cette Relique face visible dans une Zone Action/Piège libre. À ta troisième Phase de Préparation après son activation, envoie-la au Cimetière ; invoque spécialement 1 Personnage Forêt de rang 7 ou 8 depuis ton deck, effets annulés ce tour. |
| FOR-015 | Iroko, Cœur du Monde | Mythique · Fusion | Légendaire | 10 · 3500/4000 | Nature | Ancêtre | Doit d'abord être invoqué par « Racines du Cœur-Monde ». À son invocation : crée autant de Jetons Sylve que possible, jusqu'à 3. Une fois par tour : sacrifie 1 Jeton ; gagne 800 PV et cette carte gagne 400 ATK ce tour. |

## Famille Lagune

Identité de jeu : contrôle souple, renvoi en main, positions Défense et exploitation des cartes déplacées.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| LAG-001 | Petit Piroguier des Brumes | Personnage | Commune | 1 · 500/700 | Eau | Village | Si cette carte est renvoyée du terrain dans ta main par un effet : pioche 1 carte, puis défausse 1 carte. |
| LAG-002 | Crabe Gardien des Berges | Personnage | Commune | 2 · 700/1500 | Eau | Forêt | Une fois par tour, lorsqu'il passe en Défense : il gagne 300 DEF jusqu'à la fin du tour. |
| LAG-003 | Crocodile de la Lagune Calme | Personnage simple | Commune | 4 · 1900/1700 | Eau | Savane | Aucun effet. |
| LAG-004 | Plongeuse aux Perles Bleues | Personnage | Rare | 4 · 1600/1800 | Eau | Village | À son invocation : cible 1 carte Lagune dans ton Cimetière ; place-la sous ton deck, puis gagne 300 PV. |
| LAG-005 | Gardienne des Palétuviers | Personnage | Rare | 5 · 2100/2400 | Nature | Forêt | Une fois par tour : renvoie 1 autre carte Lagune que tu contrôles dans ta main ; cible 1 Personnage adverse face visible et passe-le en Défense. |
| LAG-006 | Prince des Courants Croisés | Personnage | Épique | 6 · 2500/2200 | Eau | Royaume | Lorsqu'une carte est renvoyée du terrain dans une main : cette carte gagne 300 ATK jusqu'à la fin du tour. Cet effet peut s'appliquer deux fois par tour. |
| LAG-007 | Hippopotame des Eaux Profondes | Personnage | Épique | 8 · 2900/3300 | Eau | Savane | Ne peut pas être renvoyé dans une main par un effet adverse. Une fois par tour : renvoie 1 autre carte que tu contrôles dans ta main ; détruis 1 Action ou Piège face visible adverse. |
| LAG-008 | Courant Inverse | Action `quick` | Commune | — | Eau | — | Cible 1 Personnage Lagune que tu contrôles et 1 Personnage adverse de rang inférieur ou égal ; renvoie les deux dans la main de leur propriétaire. |
| LAG-009 | Marée des Palétuviers | Action `continuous` | Rare | — | Nature | Forêt | Une fois par tour, lorsqu'une carte Lagune revient dans ta main depuis le terrain : gagne 400 PV et tu peux changer la position d'un Personnage sur le terrain. |
| LAG-010 | Chant de la Lagune Sans Fond | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation ancestrale : sacrifie des Personnages Eau dont le total des rangs est au moins 9 et renvoie 1 carte de ton terrain dans ta main ; invoque spécialement « Reine des Eaux d'Ébène » depuis ta Réserve des Mythiques. |
| LAG-011 | Filet des Piroguiers | Piège `normal` | Commune | — | Eau | Village | Lorsqu'un Personnage adverse est invoqué : s'il est de rang 5 ou moins, passe-le en Défense et annule ses effets jusqu'à la fin du tour. |
| LAG-012 | Reflux Absolu | Piège `counter` | Rare | — | Eau | — | Lorsqu'un effet doit détruire une carte Lagune que tu contrôles : renvoie cette carte dans ta main ; annule l'effet qui devait la détruire. |
| LAG-013 | Lagune aux Reflets d'Argent | Terrain | Rare | — | Eau | Ancêtre | Les Personnages Lagune gagnent 200 DEF. La première fois par tour qu'une carte revient dans une main depuis le terrain, son propriétaire pioche 1 carte puis défausse 1 carte. |
| LAG-014 | Pagaie des Deux Rives | Relique `equipment` | Épique | — | Vent | Village | Équipe un Personnage Lagune. Il gagne 300 ATK/DEF. Une fois par tour : renvoie cette Relique dans ta main ; le Personnage équipé ne peut pas être détruit au combat ce tour. |
| LAG-015 | Reine des Eaux d'Ébène | Mythique · Ancestrale | Légendaire | 9 · 3300/3600 | Eau | Ancêtre | Doit d'abord être invoquée par « Chant de la Lagune Sans Fond ». À son invocation : renvoie jusqu'à 2 cartes adverses face visible dans la main de leur propriétaire. Une fois par tour, lorsqu'une carte revient dans une main : cible 1 carte sur le terrain ; elle ne peut ni attaquer ni activer ses effets ce tour. |

## Famille Savane

Identité de jeu : domination de la Phase de Combat, meute, bonus d'ATK et attaques successives contrôlées.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| SAV-001 | Suricate de l'Aube | Personnage | Commune | 1 · 600/500 | Terre | Forêt | À son invocation : regarde la carte du dessus de ton deck. Si c'est un Personnage Savane, tu peux la révéler et l'ajouter à ta main, puis place 1 carte de ta main sous le deck. |
| SAV-002 | Gazelle aux Sabots de Vent | Personnage | Commune | 3 · 1500/900 | Vent | Forêt | Si elle attaque directement, elle gagne 300 ATK pendant le calcul des dégâts uniquement. |
| SAV-003 | Buffle des Plaines Rouges | Personnage simple | Commune | 4 · 2000/1600 | Terre | Dozo | Aucun effet. |
| SAV-004 | Hyène au Rire de Feu | Personnage | Rare | 4 · 1800/1400 | Feu | Maquis | Lorsqu'un autre Personnage Savane détruit un adversaire au combat : cette carte peut attaquer une fois supplémentaire ce tour, mais uniquement un Personnage. |
| SAV-005 | Éclaireuse des Termitières | Personnage | Rare | 5 · 2200/2000 | Terre | Dozo | À son invocation : cible 1 Personnage adverse ; il perd 300 ATK pour chaque autre Personnage Savane que tu contrôles, jusqu'à la fin du tour. |
| SAV-006 | Éléphant au Front d'Orage | Personnage | Épique | 6 · 2600/2400 | Vent | Forêt | Lorsqu'il attaque un Personnage en Défense, si son ATK dépasse la DEF adverse, inflige à l'adversaire la moitié de la différence en dégâts, arrondie au supérieur. |
| SAV-007 | Lionne Commandante | Personnage | Épique | 8 · 3100/2700 | Feu | Royaume | Les autres Personnages Savane gagnent 300 ATK pendant ta Phase de Combat. Une fois par tour, après qu'un autre Personnage Savane a attaqué : change sa position en Défense. |
| SAV-008 | Ruée de la Meute | Action `normal` | Commune | — | Terre | — | Jusqu'à 3 Personnages Savane que tu contrôles gagnent 300 ATK ce tour. Après leur attaque, ils passent en Défense. |
| SAV-009 | Bond au Dernier Instant | Action `quick` | Rare | — | Vent | — | Pendant la Phase de Combat : cible 1 Personnage Savane ; il gagne 700 ATK pendant ce calcul des dégâts uniquement. |
| SAV-010 | Rugissement du Soleil Premier | Action `normal` | Épique | — | Feu | Ancêtre | Invocation Fusion : envoie depuis ton terrain au Cimetière « Éléphant au Front d'Orage » et « Lionne Commandante » ; invoque spécialement « Lion-Soleil des Plaines Infinies » depuis ta Réserve des Mythiques. |
| SAV-011 | Poussière Aveuglante | Piège `normal` | Commune | — | Vent | — | Lorsqu'un Personnage adverse déclare une attaque : il perd 1000 ATK pendant ce combat. Après le combat, s'il est encore sur le terrain, passe-le en Défense. |
| SAV-012 | Cercle des Défenses | Piège `continuous` | Rare | — | Terre | Royaume | Une fois par tour, lorsqu'un Personnage Savane est ciblé par une attaque : tu peux transférer cette attaque vers un autre Personnage Savane que tu contrôles. |
| SAV-013 | Plaine du Soleil Rouge | Terrain | Rare | — | Feu | Dozo | Les Personnages Savane gagnent 300 ATK pendant leur Phase de Combat et perdent 100 DEF. Lorsqu'un Personnage Savane détruit un adversaire au combat, son contrôleur gagne 200 PV. |
| SAV-014 | Lance de la Première Chasse | Relique `equipment` | Épique | — | Feu | Dozo | Équipe un Personnage Savane. Il gagne 500 ATK lorsqu'il combat un Personnage de rang supérieur au sien. S'il détruit ce Personnage, pioche 1 carte. |
| SAV-015 | Lion-Soleil des Plaines Infinies | Mythique · Fusion | Légendaire | 10 · 3900/3200 | Feu | Ancêtre | Doit d'abord être invoqué par « Rugissement du Soleil Premier ». Une fois par tour, après avoir détruit un Personnage au combat : cette carte peut attaquer un autre Personnage. Elle ne peut jamais effectuer plus de 2 attaques par tour. |

## Famille Village

Identité de jeu : fabrication, Équipements, défense collective et récupération des cartes matérielles.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| VIL-001 | Apprenti Potier | Personnage | Commune | 1 · 400/900 | Terre | — | Si cette carte est envoyée du terrain au Cimetière : cible 1 Action Équipement ou Relique Équipement dans ton Cimetière ; place-la sous ton deck. |
| VIL-002 | Tisserande aux Fils de Vent | Personnage | Commune | 2 · 800/1400 | Vent | Babi | À son invocation : cible 1 Personnage Village ; il gagne 300 DEF jusqu'à la fin du prochain tour adverse. |
| VIL-003 | Maçon du Mur de Banco | Personnage simple | Commune | 4 · 1600/2200 | Terre | Royaume | Aucun effet. |
| VIL-004 | Forgeronne des Étincelles Bleues | Personnage | Rare | 4 · 1800/1700 | Feu | Royaume | À son invocation : ajoute à ta main 1 carte Équipement depuis ton deck, puis défausse 1 carte. |
| VIL-005 | Doyenne du Grenier Commun | Personnage | Rare | 5 · 2000/2500 | Nature | Ancêtre | Une fois par tour, lorsqu'une carte équipée que tu contrôles quitte le terrain : gagne 500 PV et pioche 1 carte, puis défausse 1 carte. |
| VIL-006 | Maître Artisan des Trois Métaux | Personnage | Épique | 6 · 2400/2500 | Feu | Royaume | Une fois par tour : cible 1 Équipement dans ton Cimetière ; équipe-le à une cible légale que tu contrôles. Bannit cet Équipement lorsqu'il quitte ensuite le terrain. |
| VIL-007 | Gardien du Grenier d'Argile | Personnage | Épique | 8 · 2800/3400 | Terre | Royaume | Les autres cartes Village que tu contrôles ne peuvent pas être détruites par des effets adverses une fois par tour. Cette protection s'applique à la première destruction concernée de chaque tour. |
| VIL-008 | Atelier Partagé | Action `continuous` | Commune | — | Terre | — | Une fois par tour, lorsqu'un Équipement est attaché à un Personnage : place 1 marqueur Outil ici. Retire 2 marqueurs ; pioche 1 carte, puis défausse 1 carte. |
| VIL-009 | Tablier aux Cent Poches | Action `equipment` | Rare | — | Terre | — | Équipe un Personnage Village. Il gagne 400 DEF. Une fois par tour : regarde la carte du dessus de ton deck ; si c'est un Équipement, tu peux la révéler et l'ajouter à ta main, puis place 1 carte de ta main sous le deck. |
| VIL-010 | Étincelle de la Forge Ancestrale | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation Fusion : envoie depuis ton terrain au Cimetière « Forgeronne des Étincelles Bleues », « Maître Artisan des Trois Métaux » et 1 Équipement ; invoque spécialement « Forge-Ancêtre, Main du Peuple » depuis ta Réserve des Mythiques. |
| VIL-011 | Mur de Banco Renforcé | Piège `normal` | Commune | — | Terre | Royaume | Lorsqu'un Personnage Village en Défense est attaqué : il gagne 1000 DEF pendant ce combat. |
| VIL-012 | Travail Bien Fait | Piège `counter` | Rare | — | Lumière | — | Lorsqu'un effet doit détruire ou bannir un Équipement que tu contrôles : annule l'activation et détruis sa carte. |
| VIL-013 | Grand Village des Artisans | Terrain | Rare | — | Terre | Royaume | Les Personnages Village gagnent 200 DEF. Une fois par tour, le premier Équipement que tu actives peut cibler un Personnage Village depuis ton Cimetière ; invoque d'abord ce Personnage en Défense, effets annulés, puis équipe-le. |
| VIL-014 | Marteau des Trois Métaux | Relique `equipment` | Épique | — | Feu | Royaume | Équipe un Personnage Village. Il gagne 300 ATK/DEF pour chaque autre Équipement que tu contrôles, avec un maximum de 900. Si cette carte devrait être détruite, tu peux détruire un autre Équipement que tu contrôles à la place. |
| VIL-015 | Forge-Ancêtre, Main du Peuple | Mythique · Fusion | Légendaire | 10 · 3600/3900 | Esprit | Ancêtre | Doit d'abord être invoquée par « Étincelle de la Forge Ancestrale ». À son invocation : équipe-lui jusqu'à 2 Équipements de noms différents depuis ton Cimetière. Une fois par tour : envoie 1 Équipement qu'elle porte au Cimetière ; annule la destruction d'une carte que tu contrôles. |

## Famille Maquis

Identité de jeu : convivialité imprévisible mais maîtrisée, gain de PV, circulation de la main et enchaînement d'Actions.

| Code | Nom | Catégorie / sous-type | Rareté | Rang · ATK/DEF | Attribut | Familles secondaires | Effet |
|---|---|---|---|---|---|---|---|
| MAQ-001 | Serveur aux Sandales Rapides | Personnage | Commune | 1 · 600/600 | Vent | Babi | À son invocation : tu peux renvoyer 1 autre carte Maquis que tu contrôles dans ta main ; gagne 300 PV. |
| MAQ-002 | Vendeuse d'Alloco Solaire | Personnage | Commune | 2 · 900/1300 | Feu | Babi | Une fois par tour, si tu gagnes des PV : cible 1 Personnage Maquis ; il gagne 300 ATK ce tour. |
| MAQ-003 | Videur au Grand Sourire | Personnage simple | Commune | 4 · 1800/2000 | Terre | Babi | Aucun effet. |
| MAQ-004 | DJ du Car Rapide | Personnage | Rare | 4 · 1700/1500 | Vent | Babi | La première fois par tour que tu actives une Action Maquis, cette carte gagne 400 ATK jusqu'à la fin du tour. |
| MAQ-005 | Cuisinière de Minuit | Personnage | Rare | 5 · 2100/2300 | Feu | Village | À son invocation : révèle les 3 cartes du dessus de ton deck ; ajoute 1 Action Maquis révélée à ta main et replace les autres sous le deck dans l'ordre de ton choix. |
| MAQ-006 | Patron du Coin Lumineux | Personnage | Épique | 6 · 2500/2300 | Lumière | Babi | Une fois par tour, après la résolution d'une Action Maquis : gagne 400 PV. Si tu as gagné au moins 800 PV ce tour, pioche 1 carte puis défausse 1 carte. |
| MAQ-007 | Légende du Quartier Sans Sommeil | Personnage | Épique | 7 · 2800/2600 | Lumière | Babi | Une fois par tour : défausse 1 Action ; cette carte peut effectuer une seconde attaque sur un Personnage ce tour. Les dégâts de combat infligés lors de cette seconde attaque sont divisés par deux, arrondis au supérieur. |
| MAQ-008 | Tournée Générale | Action `normal` | Commune | — | Lumière | — | Chaque joueur gagne 500 PV. Tu pioches ensuite 1 carte puis défausses 1 carte. |
| MAQ-009 | Commande Express | Action `quick` | Rare | — | Vent | Babi | Cible 1 Personnage Maquis ; renvoie-le dans ta main, puis invoque spécialement depuis ta main 1 Personnage Maquis de rang inférieur. |
| MAQ-010 | Banquet des Étoiles Urbaines | Action `normal` | Épique | — | Esprit | Ancêtre | Invocation ancestrale : défausse 2 Actions Maquis de noms différents et sacrifie des Personnages Maquis dont le total des rangs est au moins 8 ; invoque spécialement « Grand Maquisard Cosmique » depuis ta Réserve des Mythiques. |
| MAQ-011 | Plateau Très Glissant | Piège `normal` | Commune | — | Eau | Lagune | Lorsqu'un Personnage adverse déclare une attaque : annule l'attaque et renvoie dans ta main 1 Personnage Maquis que tu contrôles. |
| MAQ-012 | Addition Contestée | Piège `counter` | Rare | — | Ombre | Babi | Lorsqu'un effet adverse ferait perdre des PV en dehors du combat : défausse 1 carte ; annule cet effet et gagne 300 PV. |
| MAQ-013 | Maquis des Mille Saveurs | Terrain | Rare | — | Feu | Babi | Les Personnages Maquis gagnent 200 ATK/DEF. Une fois par tour, lorsqu'un joueur gagne des PV par l'effet d'une autre carte, le propriétaire de ce Terrain gagne 200 PV. Ce gain ne peut pas déclencher cet effet. |
| MAQ-014 | Marmite Qui Ne Se Vide Jamais | Relique `action` | Épique | — | Feu | Village | Place cette Relique face visible dans une Zone Action/Piège libre avec 3 marqueurs Portion. Une fois par tour : retire 1 marqueur ; gagne 600 PV. Sans marqueur, envoie cette carte au Cimetière et pioche 1 carte. |
| MAQ-015 | Grand Maquisard Cosmique | Mythique · Ancestrale | Légendaire | 9 · 3400/3100 | Lumière | Babi | Doit d'abord être invoqué par « Banquet des Étoiles Urbaines ». À son invocation : gagne 1000 PV, puis ajoute à ta main 1 Action Maquis depuis ton Cimetière. Une fois par tour, après la résolution de ta deuxième Action du tour : détruis 1 carte adverse face visible. |

## Matrice récapitulative

| Famille principale | Personnages | Actions | Pièges | Terrains | Reliques | Mythiques | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| Babi | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Royaume | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Ancêtre | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Masque | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Dozo | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Forêt | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Lagune | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Savane | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Village | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| Maquis | 7 | 3 | 2 | 1 | 1 | 1 | 15 |
| **Total** | **70** | **30** | **20** | **10** | **10** | **10** | **150** |

## Points à valider avant le schéma Supabase

1. La distribution de catégories par famille.
2. Les dix identités mécaniques et leur niveau de complexité pour le set de lancement.
3. Les dix conditions d'invocation Mythique.
4. La présence d'une seule condition de victoire alternative dans le set : « Calebasse des Huit Noms ».
5. Les valeurs initiales d'ATK/DEF et les montants de dégâts, bonus et récupération de PV.
6. La terminologie finale des opérations du moteur : annuler une activation, annuler un effet, empêcher une destruction, envoyer, défausser, sacrifier, bannir et renvoyer.
