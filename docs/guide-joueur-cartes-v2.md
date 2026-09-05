# MystiCartes V2 — Guide simple des règles et des 150 cartes

> Guide joueur en français simple. Le GDD officiel et le catalogue restent les sources de vérité si une formulation semble ambiguë.

## Où placer les images

Place les illustrations des cartes dans `assets/images/cards/`. Le nom du fichier est le code de la carte en minuscules, suivi de `.png`.

Exemples :

- `BAB-001` → `assets/images/cards/bab-001.png`
- `ROY-015` → `assets/images/cards/roy-015.png`
- `ANC-014` → `assets/images/cards/anc-014.png`
- `MAQ-015` → `assets/images/cards/maq-015.png`

Les décors vont dans `assets/images/backgrounds/` et les logos ou boutons illustrés dans `assets/images/ui/`. Si `art_url` est vide dans Supabase, l'application cherche automatiquement l'image locale portant le code de la carte.

## Le but du jeu

Chaque joueur commence avec **8000 PV**. Tu gagnes immédiatement si les PV adverses tombent à 0, si l’adversaire doit piocher avec un deck vide, s’il abandonne, ou si une carte annonce une condition de victoire spéciale.

Exemple : ton Personnage possède 2000 ATK et attaque directement. L’adversaire passe de 8000 à 6000 PV.

## Construire un deck

- Deck principal : exactement **40 cartes**.
- Réserve des Mythiques : de **0 à 15 Mythiques**.
- Maximum **3 exemplaires du même nom**, deck et Réserve Mythique combinés.
- Les Mythiques ne vont jamais dans le deck principal.

## Le terrain

Chaque joueur possède 5 Zones Personnage, 5 Zones Action/Piège, 1 Zone Terrain, un Deck, une main, un Cimetière, une Zone de bannissement et une Réserve des Mythiques. Une carte ne peut pas être jouée si la zone nécessaire est pleine.

## Début et déroulement d’un tour

Chaque joueur commence avec 5 cartes. Le premier joueur est tiré au sort. Un tour suit cet ordre :

1. **Pioche** : pioche 1 carte. Le joueur qui commence ne pioche pas à son premier tour.
2. **Préparation** : certains effets se déclenchent ici.
3. **Phase principale 1** : invoque, pose et active tes cartes.
4. **Combat** : attaque avec tes Personnages en position Attaque.
5. **Phase principale 2** : prépare ton terrain après le combat.
6. **Fin** : les bonus « ce tour » disparaissent. Si tu as plus de 6 cartes, défausse jusqu’à 6.

Le joueur qui commence ne peut pas attaquer pendant son premier tour.

## Invoquer un Personnage

Tu as droit à **une seule Invocation normale OU Pose normale de Personnage par tour** :

- Rang 1 à 4 : aucun sacrifice.
- Rang 5 à 6 : sacrifie 1 Personnage.
- Rang 7 à 8 : sacrifie 2 Personnages.
- Rang 9 à 10 : Mythique uniquement, jamais d’invocation normale.

Une Invocation normale place le Personnage face visible en Attaque. Une Pose normale le place face cachée en Défense. Poser une Action ou un Piège ne consomme pas ce droit.

Exemple : pour invoquer un Rang 6, envoie un Personnage de ton terrain au Cimetière comme sacrifice. Ce sacrifice n’est pas une destruction.

## Le combat

- Attaque directe : possible seulement si l’adversaire ne contrôle aucun Personnage.
- Attaque contre Attaque : compare ATK contre ATK. Le plus faible est détruit et son contrôleur perd la différence en PV.
- Attaque contre Défense : compare ATK contre DEF. Si ATK est supérieure, le défenseur est détruit sans dégâts aux PV. Si ATK est inférieure, l’attaquant n’est pas détruit mais son contrôleur perd la différence.
- En cas d’égalité ATK/ATK, les deux sont détruits sans dégâts. En cas d’égalité ATK/DEF, rien ne se passe.
- Un Personnage attaque une fois par tour, sauf effet contraire.
- Un défenseur face cachée est retourné avant le calcul, ce qui peut déclencher un effet de Retournement.

## Actions, Pièges, Terrains et Reliques

- Action normale : jouée en Phase principale, puis envoyée au Cimetière.
- Action rapide : utilisable rapidement ; pendant le tour adverse, elle doit normalement avoir été posée auparavant.
- Piège : posé face cachée et normalement inutilisable le tour de sa pose.
- Contre-Piège : réponse de Vitesse 3, généralement contrable seulement par une autre Vitesse 3.
- Terrain : un seul par joueur ; le nouveau remplace l’ancien.
- Relique : suit son mode et son texte précis.

## Chaîne et priorité

Après une activation, l’adversaire peut répondre. Les joueurs alternent. Après deux passes consécutives, la Chaîne se résout à l’envers : la dernière carte activée agit en premier.

Exemple : tu actives une Action de Vitesse 1. L’adversaire répond avec un Piège de Vitesse 2. Le Piège se résout d’abord, puis ton Action si elle n’a pas été annulée.

La victoire est vérifiée après chaque effet et chaque combat. Si un joueur gagne pendant une Chaîne, les effets restants ne sont pas résolus.

## Cimetière, bannissement, Jetons et marqueurs

- Défausser, sacrifier et détruire sont trois actions différentes.
- Une protection contre la destruction ne protège pas d’un sacrifice, d’un bannissement ou d’un renvoi en main.
- Les Jetons peuvent combattre et parfois être sacrifiés, mais disparaissent lorsqu’ils quittent le terrain.
- Les marqueurs restent sur leur carte jusqu’à ce qu’un effet les retire ou que la carte quitte le terrain.
- Une cible doit être légale à l’activation et à la résolution. Si elle ne l’est plus, l’effet échoue mais le coût payé n’est pas remboursé.

## Guide des cartes

Dans les fiches ci-dessous, « comment la jouer » explique la règle générale. Le texte de l’effet reste prioritaire.

## Famille Babi

**Style de jeu :** jeu rapide et urbain : changer les positions, utiliser des Actions rapides et gêner les cartes adverses.

### BAB-001 — Apprenti du Gbaka

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 2 · 900/1200.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : tu peux piocher 1 carte, puis défausse 1 carte.

### BAB-002 — Messagère Wôrô-Wôrô

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 3 · 1400/1000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : tu peux changer la position de combat d'un autre Personnage que tu contrôles.
- **Autres familles compatibles :** Maquis.

### BAB-003 — Gardien du Carrefour

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 1800/1700.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.

### BAB-004 — Danseuse des Néons

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Lumière · **Rang/ATK/DEF :** 4 · 1700/1500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Une fois par tour, après l'activation d'une Action rapide : cette carte gagne 300 ATK jusqu'à la fin du tour.
- **Autres familles compatibles :** Maquis.

### BAB-005 — Hacker du Marché

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Ombre · **Rang/ATK/DEF :** 5 · 2100/1800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** À son invocation : cible 1 carte posée dans une Zone Action/Piège adverse ; regarde-la. Tu peux la renvoyer dans la main de son propriétaire.

### BAB-006 — Champion du Bitume

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Feu · **Rang/ATK/DEF :** 6 · 2400/2000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour, si cette carte détruit un Personnage au combat : pioche 1 carte, puis défausse 1 carte.
- **Autres familles compatibles :** Savane.

### BAB-007 — Reine du Plateau

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Lumière · **Rang/ATK/DEF :** 7 · 2700/2500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : tu peux renvoyer 1 autre carte Babi que tu contrôles dans ta main ; cette carte peut attaquer directement ce tour, mais les dégâts de cette attaque sont divisés par deux, arrondis au supérieur.
- **Autres familles compatibles :** Royaume.

### BAB-008 — Trajet Express

- **Type :** Action `quick` · **Rareté :** Commune · **Attribut :** Vent.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage Babi que tu contrôles ; change sa position de combat. S'il passe en Attaque, il gagne 300 ATK ce tour.

### BAB-009 — Réseau Saturé

- **Type :** Action `normal` · **Rareté :** Rare · **Attribut :** Ombre.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Cible 1 carte posée dans une Zone Action/Piège adverse ; renvoie-la dans la main de son propriétaire.

### BAB-010 — Battement de la Ville

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Lumière.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation Fusion : envoie depuis ton terrain au Cimetière « Messagère Wôrô-Wôrô » et « Champion du Bitume » ; invoque spécialement « Génie d'Abidjan, Cœur Électrique » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### BAB-011 — Feu Rouge Mystique

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Feu.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : annule cette attaque, puis passe l'attaquant en Défense s'il peut changer de position.

### BAB-012 — Coupure de Courant

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Ombre.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'une Action est activée : défausse 1 carte ; annule l'activation et détruis cette Action.

### BAB-013 — Abidjan Minuit

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Lumière.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Tous les Personnages Babi gagnent 200 ATK/DEF. La première Action rapide que tu actives pendant chaque tour ne peut pas être annulée par une Vitesse 2.
- **Autres familles compatibles :** Maquis.

### BAB-014 — Smartphone des Ancêtres

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe uniquement un Personnage Babi. Une fois par tour : regarde la carte du dessus de ton deck ; laisse-la au-dessus ou place-la sous le deck.
- **Autres familles compatibles :** Ancêtre.

### BAB-015 — Génie d'Abidjan, Cœur Électrique

- **Type :** Mythique · Fusion · **Rareté :** Légendaire · **Attribut :** Lumière · **Rang/ATK/DEF :** 9 · 3200/2800.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Battement de la Ville  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Battement de la Ville ». À son invocation : renvoie jusqu'à 2 cartes posées adverses dans la main de leur propriétaire. Une fois par tour, lorsqu'une Action rapide est activée : cette carte gagne 500 ATK jusqu'à la fin du tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Royaume

**Style de jeu :** sacrifier de petits Personnages pour invoquer de puissants combattants et protéger son terrain.

### ROY-001 — Page aux Bracelets d'Or

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Lumière · **Rang/ATK/DEF :** 1 · 400/1000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si cette carte est sacrifiée pour l'invocation d'un Personnage Royaume : pioche 1 carte.
- **Autres familles compatibles :** Village.

### ROY-002 — Lancière de la Porte Rouge

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Feu · **Rang/ATK/DEF :** 3 · 1500/1200.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.

### ROY-003 — Garde du Tambour Royal

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 1700/2000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Les autres Personnages Royaume que tu contrôles ne peuvent pas être ciblés par une attaque tant que cette carte est en position d'Attaque.
- **Autres familles compatibles :** Village.

### ROY-004 — Stratège des Sept Cours

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Esprit · **Rang/ATK/DEF :** 4 · 1600/1800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : regarde les 3 cartes du dessus de ton deck ; ajoute 1 carte Royaume parmi elles à ta main et replace les autres sous le deck dans l'ordre de ton choix.

### ROY-005 — Cavalier au Manteau Pourpre

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Vent · **Rang/ATK/DEF :** 5 · 2200/1700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Si un Personnage a été sacrifié pour son invocation, cette carte gagne 400 ATK pendant le tour de son invocation.
- **Autres familles compatibles :** Savane.

### ROY-006 — Reine des Remparts Solaires

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Lumière · **Rang/ATK/DEF :** 6 · 2300/2600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'une carte Royaume que tu contrôles devrait être détruite par un effet : tu peux défausser 1 carte ; elle n'est pas détruite.

### ROY-007 — Roi au Serment de Fer

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Terre · **Rang/ATK/DEF :** 8 · 3000/2700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** À son invocation par sacrifice : cible jusqu'à 2 Personnages Royaume dans ton Cimetière de rang 4 ou moins ; invoque-les spécialement en Défense, effets annulés ce tour.
- **Autres familles compatibles :** Ancêtre.

### ROY-008 — Décret de Mobilisation

- **Type :** Action `normal` · **Rareté :** Commune · **Attribut :** Lumière.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Ajoute à ta main 1 Personnage Royaume de rang 4 ou moins depuis ton deck.

### ROY-009 — Relève de la Garde

- **Type :** Action `quick` · **Rareté :** Rare · **Attribut :** Terre.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Lorsqu'un Personnage Royaume devrait être détruit : sacrifie 1 autre Personnage que tu contrôles ; empêche cette destruction.

### ROY-010 — Couronnement des Sept Tambours

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation ancestrale : sacrifie des Personnages que tu contrôles dont le total des rangs est au moins 9 ; invoque spécialement « Souverain des Sept Tambours » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### ROY-011 — Herse de Lumière

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Lumière.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : cible cet attaquant ; il perd 800 ATK ce tour. S'il passe sous l'ATK de sa cible, annule l'attaque.

### ROY-012 — Sceau Inviolable

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Esprit.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet cible une carte Royaume que tu contrôles : annule l'activation et détruis la carte ayant activé cet effet.
- **Autres familles compatibles :** Ancêtre.

### ROY-013 — Cour des Mille Étendards

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Terre.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Royaume gagnent 200 DEF. Chaque fois que tu sacrifies un Personnage, place 1 marqueur Serment ici. À 3 marqueurs ou plus, tes Personnages Royaume gagnent aussi 300 ATK.
- **Autres familles compatibles :** Village.

### ROY-014 — Couronne du Pacte Ancien

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Royaume de rang 5 ou plus. Il gagne 400 ATK/DEF. S'il quitte le terrain, ajoute cette Relique à ta main au lieu de l'envoyer au Cimetière.
- **Autres familles compatibles :** Ancêtre.

### ROY-015 — Souverain des Sept Tambours

- **Type :** Mythique · Ancestrale · **Rareté :** Légendaire · **Attribut :** Esprit · **Rang/ATK/DEF :** 10 · 3700/3400.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Couronnement des Sept Tambours  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Couronnement des Sept Tambours ». À son invocation : jusqu'à 2 Personnages Royaume dans ton Cimetière reviennent spécialement en Défense. Une fois par tour : sacrifie 1 autre Personnage ; annule l'activation d'un effet de Vitesse 2 et détruis sa carte.
- **Autres familles compatibles :** Ancêtre.

## Famille Ancêtre

**Style de jeu :** utiliser le Cimetière comme une ressource et récupérer les cartes déjà jouées.

### ANC-001 — Porteur de Cauris

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Esprit · **Rang/ATK/DEF :** 1 · 300/900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si cette carte est envoyée du terrain au Cimetière : place la carte du dessus de ton deck au Cimetière.
- **Autres familles compatibles :** Village.

### ANC-002 — Enfant des Songes Clairs

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Lumière · **Rang/ATK/DEF :** 2 · 800/1300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : cible 1 carte Ancêtre dans ton Cimetière ; place-la sous ton deck.
- **Autres familles compatibles :** Village.

### ANC-003 — Veilleuse du Foyer Invisible

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Feu · **Rang/ATK/DEF :** 3 · 1300/1700.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Village.

### ANC-004 — Messager de la Première Pluie

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Eau · **Rang/ATK/DEF :** 4 · 1700/1600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : envoie 1 carte Ancêtre depuis ton deck au Cimetière, sauf « Messager de la Première Pluie ».
- **Autres familles compatibles :** Lagune.

### ANC-005 — Gardienne des Noms Oubliés

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Esprit · **Rang/ATK/DEF :** 5 · 2100/2200.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : cible 1 Personnage de rang 4 ou moins dans ton Cimetière ; mélange cette carte dans le deck et ajoute la cible à ta main.
- **Autres familles compatibles :** Royaume.

### ANC-006 — Conseiller de l'Au-Delà

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Ombre · **Rang/ATK/DEF :** 6 · 2300/2500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Si cette carte est envoyée au Cimetière comme sacrifice ou coût : tu peux invoquer spécialement 1 Personnage Ancêtre de rang 3 ou moins depuis ton Cimetière.
- **Autres familles compatibles :** Royaume.

### ANC-007 — Matriarche aux Cent Mémoires

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Esprit · **Rang/ATK/DEF :** 8 · 2900/3100.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** À son invocation : cible jusqu'à 3 cartes Ancêtre dans ton Cimetière ; mélange-les dans le deck, puis pioche 1 carte. Cette carte gagne 100 ATK pour chaque carte ainsi mélangée.
- **Autres familles compatibles :** Village.

### ANC-008 — Parole Transmise

- **Type :** Action `normal` · **Rareté :** Commune · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Ajoute à ta main 1 carte Ancêtre depuis ton Cimetière, puis défausse 1 carte.
- **Autres familles compatibles :** Village.

### ANC-009 — Main des Aïeux

- **Type :** Action `quick` · **Rareté :** Rare · **Attribut :** Lumière.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage Ancêtre que tu contrôles et 1 Personnage adverse ; le premier gagne 600 ATK/DEF et le second perd 300 ATK/DEF ce tour.

### ANC-010 — Appel des Huit Veillées

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation ancestrale : bannis depuis ton Cimetière des Personnages Ancêtre dont le total des rangs est au moins 10 ; invoque spécialement « Mère des Premières Lueurs » depuis ta Réserve des Mythiques.

### ANC-011 — Conseil des Invisibles

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Esprit.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage que tu contrôles est détruit : invoque spécialement 1 Personnage Ancêtre de rang inférieur depuis ton Cimetière en Défense.

### ANC-012 — Refus de l'Oubli

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Lumière.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'une carte de ton Cimetière devrait être bannie par un effet adverse : annule l'activation et détruis sa carte.
- **Autres familles compatibles :** Royaume.

### ANC-013 — Bosquet des Voix Anciennes

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Nature.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'une carte est envoyée de ton terrain au Cimetière : place 1 marqueur Mémoire ici. Retire 3 marqueurs ; pioche 1 carte, puis défausse 1 carte.
- **Autres familles compatibles :** Forêt.

### ANC-014 — Calebasse des Huit Noms

- **Type :** Relique `alternative_win` · **Rareté :** Légendaire · **Attribut :** Esprit.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Active cette Relique face visible dans une Zone Action/Piège libre. Chaque fois qu'un Personnage Ancêtre de nom différent est envoyé depuis ton terrain au Cimetière, place 1 marqueur Nom ici. Au début de ta Phase de Préparation, si cette carte possède 8 marqueurs Nom, tu remportes le duel.
- **Autres familles compatibles :** Village.

### ANC-015 — Mère des Premières Lueurs

- **Type :** Mythique · Ancestrale · **Rareté :** Légendaire · **Attribut :** Lumière · **Rang/ATK/DEF :** 10 · 3500/3800.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Appel des Huit Veillées  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoquée par « Appel des Huit Veillées ». À son invocation : mélange jusqu'à 5 cartes de ton Cimetière dans le deck, puis gagne 300 PV par carte mélangée. Une fois par tour, si une carte Ancêtre quitte ton terrain : pioche 1 carte.
- **Autres familles compatibles :** Village.

## Famille Masque

**Style de jeu :** poser des Personnages face cachée, les retourner et surprendre l’adversaire.

### MAS-001 — Porte-Masque Novice

- **Type :** Personnage · retournement · **Rareté :** Commune · **Attribut :** Esprit · **Rang/ATK/DEF :** 2 · 700/1400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Retournement : pioche 1 carte, puis défausse 1 carte.
- **Autres familles compatibles :** Village.

### MAS-002 — Danseur aux Pas Croisés

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 3 · 1400/1300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Une fois par tour : change la position de combat de cette carte. Si elle passe en Défense, elle gagne 300 DEF ce tour.
- **Autres familles compatibles :** Babi.

### MAS-003 — Sentinelle au Visage de Bois

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Nature · **Rang/ATK/DEF :** 4 · 1600/2100.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Forêt.

### MAS-004 — Rieuse aux Deux Visages

- **Type :** Personnage · retournement · **Rareté :** Rare · **Attribut :** Ombre · **Rang/ATK/DEF :** 4 · 1700/1700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Retournement : cible 1 Personnage face visible adverse ; son ATK et sa DEF sont échangées jusqu'à la fin du tour.
- **Autres familles compatibles :** Maquis.

### MAS-005 — Sculpteur des Gestes Secrets

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Terre · **Rang/ATK/DEF :** 5 · 2100/2300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** À son invocation : tu peux poser face cachée 1 Personnage Masque de rang 4 ou moins depuis ta main dans une Zone Personnage libre. Cette pose ne consomme pas ta Pose normale.
- **Autres familles compatibles :** Village.

### MAS-006 — Masque Dan, Gardien des Seuils

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Esprit · **Rang/ATK/DEF :** 6 · 2400/2500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Les Personnages face cachée que tu contrôles ne peuvent pas être ciblés par des effets adverses. Une fois par tour : retourne face cachée en Défense 1 autre Personnage Masque face visible que tu contrôles.
- **Autres familles compatibles :** Ancêtre.

### MAS-007 — Maîtresse du Ballet Invisible

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Vent · **Rang/ATK/DEF :** 7 · 2700/2800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : cible 1 Personnage sur le terrain ; passe-le en Défense face visible. Si c'était un Personnage Masque que tu contrôles, tu peux ensuite le retourner face cachée.
- **Autres familles compatibles :** Ancêtre.

### MAS-008 — Changement de Visage

- **Type :** Action `quick` · **Rareté :** Commune · **Attribut :** Ombre.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage Masque que tu contrôles ; retourne-le face cachée en Défense ou face visible dans sa position actuelle.

### MAS-009 — Danse de Révélation

- **Type :** Action `normal` · **Rareté :** Rare · **Attribut :** Lumière.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Retourne face visible jusqu'à 2 Personnages face cachée sur le terrain. Les effets de retournement des Personnages Masque que tu contrôles ainsi révélés peuvent s'activer.

### MAS-010 — Rythme des Mille Visages

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation Fusion : envoie depuis ton terrain au Cimetière « Rieuse aux Deux Visages » et « Masque Dan, Gardien des Seuils » ; invoque spécialement « Masque du Premier Rythme » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### MAS-011 — Faux Mouvement

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Vent.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse cible un Personnage face cachée pour une attaque : change la cible vers un autre Personnage que tu contrôles, si possible.

### MAS-012 — Visage Interdit

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Ombre.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet adverse doit révéler ou retourner face visible une de tes cartes face cachée : annule l'activation et détruis sa carte.
- **Autres familles compatibles :** Dozo.

### MAS-013 — Place des Danses Secrètes

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Esprit.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Masque gagnent 200 DEF. La première fois par tour qu'un Personnage est retourné face visible, son contrôleur gagne 300 PV.
- **Autres familles compatibles :** Village.

### MAS-014 — Ciseau du Maître Sculpteur

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Terre.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Masque. Il gagne 300 ATK/DEF. Une fois par tour, s'il a été retourné face visible ce tour : tu peux poser 1 Piège depuis ta main.
- **Autres familles compatibles :** Village.

### MAS-015 — Masque du Premier Rythme

- **Type :** Mythique · Fusion · **Rareté :** Légendaire · **Attribut :** Esprit · **Rang/ATK/DEF :** 9 · 3100/3300.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Rythme des Mille Visages  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Rythme des Mille Visages ». À son invocation : retourne face cachée en Défense jusqu'à 2 Personnages adverses. Une fois par tour, lorsqu'une carte est retournée face visible : annule ses effets jusqu'à la fin du tour ou fais gagner 500 ATK à cette carte ce tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Dozo

**Style de jeu :** marquer des Proies, les affaiblir puis les éliminer.

### DOZ-001 — Apprenti Pisteur

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Nature · **Rang/ATK/DEF :** 1 · 500/800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : regarde la carte du dessus du deck adverse et replace-la au-dessus.
- **Autres familles compatibles :** Forêt.

### DOZ-002 — Archère des Hautes Herbes

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 3 · 1500/1000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si elle attaque un Personnage en Défense, elle gagne 300 ATK pendant le calcul des dégâts uniquement.
- **Autres familles compatibles :** Savane.

### DOZ-003 — Gardien au Fusil Rituel

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Feu · **Rang/ATK/DEF :** 4 · 1800/1800.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Savane.

### DOZ-004 — Lecteur de Traces

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 1600/1900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : ajoute à ta main 1 Piège Dozo depuis ton deck, puis place 1 carte de ta main sous ton deck.
- **Autres familles compatibles :** Forêt.

### DOZ-005 — Chasseuse au Manteau Brun

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Nature · **Rang/ATK/DEF :** 5 · 2200/1900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : cible 1 Personnage adverse face visible ; place 1 marqueur Proie sur lui. Cette carte gagne 300 ATK lorsqu'elle combat un Personnage avec un marqueur Proie.
- **Autres familles compatibles :** Savane.

### DOZ-006 — Maître des Collets

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Terre · **Rang/ATK/DEF :** 6 · 2300/2600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Tu peux activer les Pièges Dozo le tour où ils sont posés, mais seulement pendant ton propre tour. Une seule fois par tour.
- **Autres familles compatibles :** Forêt.

### DOZ-007 — Capitaine de la Chasse Nocturne

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Ombre · **Rang/ATK/DEF :** 8 · 3000/2800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** À son invocation : place 1 marqueur Proie sur chaque Personnage adverse face visible. Une fois par tour, après la destruction au combat d'une Proie : bannis cette Proie au lieu de l'envoyer au Cimetière.
- **Autres familles compatibles :** Savane.

### DOZ-008 — Piste Fraîche

- **Type :** Action `normal` · **Rareté :** Commune · **Attribut :** Terre.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Cible 1 Personnage adverse face visible ; place 1 marqueur Proie sur lui, puis ajoute à ta main 1 Personnage Dozo de rang 4 ou moins depuis ton deck.

### DOZ-009 — Tir de Sommation

- **Type :** Action `quick` · **Rareté :** Rare · **Attribut :** Feu.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage avec un marqueur Proie ; il perd 700 ATK ce tour. S'il est en Défense, il perd aussi 700 DEF ce tour.

### DOZ-010 — Serment de la Lune des Chasseurs

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Ombre.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation ancestrale : sacrifie 1 Personnage Dozo de rang 6 ou plus et bannis 2 Pièges depuis ton Cimetière ; invoque spécialement « Maître Dozo de la Lune Noire » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### DOZ-011 — Collet des Hautes Herbes

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Nature.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : cible l'attaquant ; annule l'attaque, passe-le en Défense et place 1 marqueur Proie sur lui.
- **Autres familles compatibles :** Savane.

### DOZ-012 — Dernier Coup de Sifflet

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Vent.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet d'un Personnage avec un marqueur Proie est activé : annule l'activation et bannis ce Personnage.

### DOZ-013 — Campement sous la Lune

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Ombre.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Dozo gagnent 200 ATK/DEF. Une fois par tour, lorsqu'un Piège est activé : place 1 marqueur Proie sur 1 Personnage adverse face visible.
- **Autres familles compatibles :** Savane.

### DOZ-014 — Corne du Premier Buffle

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Terre.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Dozo. Il gagne 400 ATK. Lorsqu'il détruit une Proie au combat : tu peux poser 1 Piège Dozo directement depuis ta main.
- **Autres familles compatibles :** Savane.

### DOZ-015 — Maître Dozo de la Lune Noire

- **Type :** Mythique · Ancestrale · **Rareté :** Légendaire · **Attribut :** Ombre · **Rang/ATK/DEF :** 10 · 3600/3500.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Serment de la Lune des Chasseurs  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Serment de la Lune des Chasseurs ». Les Personnages adverses avec un marqueur Proie ne peuvent pas cibler d'autres cartes que celle-ci avec leurs attaques. Une fois par tour : bannis 1 Proie face visible, mais cette carte ne peut pas attaquer ce tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Forêt

**Style de jeu :** créer des Jetons Sylve, gagner des PV et construire progressivement un grand terrain.

### FOR-001 — Graine Qui Marche

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Nature · **Rang/ATK/DEF :** 1 · 300/600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si cette carte est envoyée du terrain au Cimetière : crée 1 Jeton Sylve en Défense (Nature, rang 1, 500 ATK/500 DEF).

### FOR-002 — Singe aux Fruits d'Or

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Nature · **Rang/ATK/DEF :** 2 · 1000/900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Une fois par tour, si tu gagnes des PV : cette carte gagne 300 ATK jusqu'à la fin du tour.
- **Autres familles compatibles :** Savane.

### FOR-003 — Antilope des Sous-Bois

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 3 · 1500/1400.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Savane.

### FOR-004 — Guérisseuse des Lianes

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Nature · **Rang/ATK/DEF :** 4 · 1500/2000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : gagne 500 PV. Une fois par tour, lorsqu'un Jeton est créé sur ton terrain : gagne 200 PV.
- **Autres familles compatibles :** Village.

### FOR-005 — Panthère des Racines

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Ombre · **Rang/ATK/DEF :** 5 · 2200/1800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Cette carte peut attaquer directement si tu contrôles un Jeton Sylve, mais les dégâts de cette attaque sont divisés par deux, arrondis au supérieur.
- **Autres familles compatibles :** Savane.

### FOR-006 — Gardien Iroko

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Terre · **Rang/ATK/DEF :** 6 · 2300/2800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : sacrifie 1 Jeton ; empêche la destruction d'une carte Forêt que tu contrôles.
- **Autres familles compatibles :** Ancêtre.

### FOR-007 — Éléphante aux Jardins Vivants

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Nature · **Rang/ATK/DEF :** 8 · 2900/3200.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** À son invocation : crée jusqu'à 2 Jetons Sylve en Défense. Les Jetons que tu contrôles gagnent 300 DEF.
- **Autres familles compatibles :** Savane.

### FOR-008 — Germination Soudaine

- **Type :** Action `quick` · **Rareté :** Commune · **Attribut :** Nature.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Crée 1 Jeton Sylve en Défense. Il ne peut pas être sacrifié pendant ce tour.

### FOR-009 — Saison des Grandes Pluies

- **Type :** Action `continuous` · **Rareté :** Rare · **Attribut :** Eau.
- **Rôle :** Soutien continu : elle reste sur le terrain après son activation.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale dans une Zone Action/Piège libre ; elle reste sur le terrain.
- **Ce qu’elle fait :** À chaque Phase de Préparation de ton tour : place 1 marqueur Graine ici. Retire 2 marqueurs ; crée 1 Jeton Sylve ou gagne 500 PV.
- **Autres familles compatibles :** Lagune.

### FOR-010 — Racines du Cœur-Monde

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation Fusion : envoie depuis ton terrain au Cimetière « Gardien Iroko » et 2 Jetons Sylve ; invoque spécialement « Iroko, Cœur du Monde » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### FOR-011 — Liane Entravante

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Nature.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : cible l'attaquant ; annule l'attaque et il ne peut pas changer de position pendant son prochain tour.

### FOR-012 — Reprise Sauvage

- **Type :** Piège `continuous` · **Rareté :** Rare · **Attribut :** Nature.
- **Rôle :** Piège continu : il est posé d’abord, puis reste face visible après son activation.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'un Personnage Forêt que tu contrôles est détruit : crée 1 Jeton Sylve en Défense.
- **Autres familles compatibles :** Ancêtre.

### FOR-013 — Forêt aux Mille Souffles

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Nature.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Forêt gagnent 200 ATK/DEF. Les Jetons Sylve gagnent 300 ATK/DEF supplémentaires.
- **Autres familles compatibles :** Ancêtre.

### FOR-014 — Graine de l'Arbre Originel

- **Type :** Relique `action` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Place cette Relique face visible dans une Zone Action/Piège libre. À ta troisième Phase de Préparation après son activation, envoie-la au Cimetière ; invoque spécialement 1 Personnage Forêt de rang 7 ou 8 depuis ton deck, effets annulés ce tour.
- **Autres familles compatibles :** Ancêtre.

### FOR-015 — Iroko, Cœur du Monde

- **Type :** Mythique · Fusion · **Rareté :** Légendaire · **Attribut :** Nature · **Rang/ATK/DEF :** 10 · 3500/4000.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Racines du Cœur-Monde  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Racines du Cœur-Monde ». À son invocation : crée autant de Jetons Sylve que possible, jusqu'à 3. Une fois par tour : sacrifie 1 Jeton ; gagne 800 PV et cette carte gagne 400 ATK ce tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Lagune

**Style de jeu :** renvoyer des cartes en main, changer les positions et contrôler le rythme du duel.

### LAG-001 — Petit Piroguier des Brumes

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Eau · **Rang/ATK/DEF :** 1 · 500/700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si cette carte est renvoyée du terrain dans ta main par un effet : pioche 1 carte, puis défausse 1 carte.
- **Autres familles compatibles :** Village.

### LAG-002 — Crabe Gardien des Berges

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Eau · **Rang/ATK/DEF :** 2 · 700/1500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'il passe en Défense : il gagne 300 DEF jusqu'à la fin du tour.
- **Autres familles compatibles :** Forêt.

### LAG-003 — Crocodile de la Lagune Calme

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Eau · **Rang/ATK/DEF :** 4 · 1900/1700.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Savane.

### LAG-004 — Plongeuse aux Perles Bleues

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Eau · **Rang/ATK/DEF :** 4 · 1600/1800.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : cible 1 carte Lagune dans ton Cimetière ; place-la sous ton deck, puis gagne 300 PV.
- **Autres familles compatibles :** Village.

### LAG-005 — Gardienne des Palétuviers

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Nature · **Rang/ATK/DEF :** 5 · 2100/2400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : renvoie 1 autre carte Lagune que tu contrôles dans ta main ; cible 1 Personnage adverse face visible et passe-le en Défense.
- **Autres familles compatibles :** Forêt.

### LAG-006 — Prince des Courants Croisés

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Eau · **Rang/ATK/DEF :** 6 · 2500/2200.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Lorsqu'une carte est renvoyée du terrain dans une main : cette carte gagne 300 ATK jusqu'à la fin du tour. Cet effet peut s'appliquer deux fois par tour.
- **Autres familles compatibles :** Royaume.

### LAG-007 — Hippopotame des Eaux Profondes

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Eau · **Rang/ATK/DEF :** 8 · 2900/3300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Ne peut pas être renvoyé dans une main par un effet adverse. Une fois par tour : renvoie 1 autre carte que tu contrôles dans ta main ; détruis 1 Action ou Piège face visible adverse.
- **Autres familles compatibles :** Savane.

### LAG-008 — Courant Inverse

- **Type :** Action `quick` · **Rareté :** Commune · **Attribut :** Eau.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage Lagune que tu contrôles et 1 Personnage adverse de rang inférieur ou égal ; renvoie les deux dans la main de leur propriétaire.

### LAG-009 — Marée des Palétuviers

- **Type :** Action `continuous` · **Rareté :** Rare · **Attribut :** Nature.
- **Rôle :** Soutien continu : elle reste sur le terrain après son activation.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale dans une Zone Action/Piège libre ; elle reste sur le terrain.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'une carte Lagune revient dans ta main depuis le terrain : gagne 400 PV et tu peux changer la position d'un Personnage sur le terrain.
- **Autres familles compatibles :** Forêt.

### LAG-010 — Chant de la Lagune Sans Fond

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation ancestrale : sacrifie des Personnages Eau dont le total des rangs est au moins 9 et renvoie 1 carte de ton terrain dans ta main ; invoque spécialement « Reine des Eaux d'Ébène » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### LAG-011 — Filet des Piroguiers

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Eau.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse est invoqué : s'il est de rang 5 ou moins, passe-le en Défense et annule ses effets jusqu'à la fin du tour.
- **Autres familles compatibles :** Village.

### LAG-012 — Reflux Absolu

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Eau.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet doit détruire une carte Lagune que tu contrôles : renvoie cette carte dans ta main ; annule l'effet qui devait la détruire.

### LAG-013 — Lagune aux Reflets d'Argent

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Eau.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Lagune gagnent 200 DEF. La première fois par tour qu'une carte revient dans une main depuis le terrain, son propriétaire pioche 1 carte puis défausse 1 carte.
- **Autres familles compatibles :** Ancêtre.

### LAG-014 — Pagaie des Deux Rives

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Vent.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Lagune. Il gagne 300 ATK/DEF. Une fois par tour : renvoie cette Relique dans ta main ; le Personnage équipé ne peut pas être détruit au combat ce tour.
- **Autres familles compatibles :** Village.

### LAG-015 — Reine des Eaux d'Ébène

- **Type :** Mythique · Ancestrale · **Rareté :** Légendaire · **Attribut :** Eau · **Rang/ATK/DEF :** 9 · 3300/3600.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Chant de la Lagune Sans Fond  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoquée par « Chant de la Lagune Sans Fond ». À son invocation : renvoie jusqu'à 2 cartes adverses face visible dans la main de leur propriétaire. Une fois par tour, lorsqu'une carte revient dans une main : cible 1 carte sur le terrain ; elle ne peut ni attaquer ni activer ses effets ce tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Savane

**Style de jeu :** attaquer vite, renforcer les combattants et mettre une forte pression.

### SAV-001 — Suricate de l'Aube

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 1 · 600/500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : regarde la carte du dessus de ton deck. Si c'est un Personnage Savane, tu peux la révéler et l'ajouter à ta main, puis place 1 carte de ta main sous le deck.
- **Autres familles compatibles :** Forêt.

### SAV-002 — Gazelle aux Sabots de Vent

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 3 · 1500/900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si elle attaque directement, elle gagne 300 ATK pendant le calcul des dégâts uniquement.
- **Autres familles compatibles :** Forêt.

### SAV-003 — Buffle des Plaines Rouges

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 2000/1600.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Dozo.

### SAV-004 — Hyène au Rire de Feu

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Feu · **Rang/ATK/DEF :** 4 · 1800/1400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Lorsqu'un autre Personnage Savane détruit un adversaire au combat : cette carte peut attaquer une fois supplémentaire ce tour, mais uniquement un Personnage.
- **Autres familles compatibles :** Maquis.

### SAV-005 — Éclaireuse des Termitières

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Terre · **Rang/ATK/DEF :** 5 · 2200/2000.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** À son invocation : cible 1 Personnage adverse ; il perd 300 ATK pour chaque autre Personnage Savane que tu contrôles, jusqu'à la fin du tour.
- **Autres familles compatibles :** Dozo.

### SAV-006 — Éléphant au Front d'Orage

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Vent · **Rang/ATK/DEF :** 6 · 2600/2400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Lorsqu'il attaque un Personnage en Défense, si son ATK dépasse la DEF adverse, inflige à l'adversaire la moitié de la différence en dégâts, arrondie au supérieur.
- **Autres familles compatibles :** Forêt.

### SAV-007 — Lionne Commandante

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Feu · **Rang/ATK/DEF :** 8 · 3100/2700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Les autres Personnages Savane gagnent 300 ATK pendant ta Phase de Combat. Une fois par tour, après qu'un autre Personnage Savane a attaqué : change sa position en Défense.
- **Autres familles compatibles :** Royaume.

### SAV-008 — Ruée de la Meute

- **Type :** Action `normal` · **Rareté :** Commune · **Attribut :** Terre.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Jusqu'à 3 Personnages Savane que tu contrôles gagnent 300 ATK ce tour. Après leur attaque, ils passent en Défense.

### SAV-009 — Bond au Dernier Instant

- **Type :** Action `quick` · **Rareté :** Rare · **Attribut :** Vent.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Pendant la Phase de Combat : cible 1 Personnage Savane ; il gagne 700 ATK pendant ce calcul des dégâts uniquement.

### SAV-010 — Rugissement du Soleil Premier

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Feu.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation Fusion : envoie depuis ton terrain au Cimetière « Éléphant au Front d'Orage » et « Lionne Commandante » ; invoque spécialement « Lion-Soleil des Plaines Infinies » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### SAV-011 — Poussière Aveuglante

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Vent.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : il perd 1000 ATK pendant ce combat. Après le combat, s'il est encore sur le terrain, passe-le en Défense.

### SAV-012 — Cercle des Défenses

- **Type :** Piège `continuous` · **Rareté :** Rare · **Attribut :** Terre.
- **Rôle :** Piège continu : il est posé d’abord, puis reste face visible après son activation.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'un Personnage Savane est ciblé par une attaque : tu peux transférer cette attaque vers un autre Personnage Savane que tu contrôles.
- **Autres familles compatibles :** Royaume.

### SAV-013 — Plaine du Soleil Rouge

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Feu.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Savane gagnent 300 ATK pendant leur Phase de Combat et perdent 100 DEF. Lorsqu'un Personnage Savane détruit un adversaire au combat, son contrôleur gagne 200 PV.
- **Autres familles compatibles :** Dozo.

### SAV-014 — Lance de la Première Chasse

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Feu.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Savane. Il gagne 500 ATK lorsqu'il combat un Personnage de rang supérieur au sien. S'il détruit ce Personnage, pioche 1 carte.
- **Autres familles compatibles :** Dozo.

### SAV-015 — Lion-Soleil des Plaines Infinies

- **Type :** Mythique · Fusion · **Rareté :** Légendaire · **Attribut :** Feu · **Rang/ATK/DEF :** 10 · 3900/3200.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Rugissement du Soleil Premier  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Rugissement du Soleil Premier ». Une fois par tour, après avoir détruit un Personnage au combat : cette carte peut attaquer un autre Personnage. Elle ne peut jamais effectuer plus de 2 attaques par tour.
- **Autres familles compatibles :** Ancêtre.

## Famille Village

**Style de jeu :** équiper les Personnages avec des outils et construire une défense solide.

### VIL-001 — Apprenti Potier

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 1 · 400/900.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Si cette carte est envoyée du terrain au Cimetière : cible 1 Action Équipement ou Relique Équipement dans ton Cimetière ; place-la sous ton deck.

### VIL-002 — Tisserande aux Fils de Vent

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 2 · 800/1400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : cible 1 Personnage Village ; il gagne 300 DEF jusqu'à la fin du prochain tour adverse.
- **Autres familles compatibles :** Babi.

### VIL-003 — Maçon du Mur de Banco

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 1600/2200.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Royaume.

### VIL-004 — Forgeronne des Étincelles Bleues

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Feu · **Rang/ATK/DEF :** 4 · 1800/1700.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : ajoute à ta main 1 carte Équipement depuis ton deck, puis défausse 1 carte.
- **Autres familles compatibles :** Royaume.

### VIL-005 — Doyenne du Grenier Commun

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Nature · **Rang/ATK/DEF :** 5 · 2000/2500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'une carte équipée que tu contrôles quitte le terrain : gagne 500 PV et pioche 1 carte, puis défausse 1 carte.
- **Autres familles compatibles :** Ancêtre.

### VIL-006 — Maître Artisan des Trois Métaux

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Feu · **Rang/ATK/DEF :** 6 · 2400/2500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : cible 1 Équipement dans ton Cimetière ; équipe-le à une cible légale que tu contrôles. Bannit cet Équipement lorsqu'il quitte ensuite le terrain.
- **Autres familles compatibles :** Royaume.

### VIL-007 — Gardien du Grenier d'Argile

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Terre · **Rang/ATK/DEF :** 8 · 2800/3400.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Les autres cartes Village que tu contrôles ne peuvent pas être détruites par des effets adverses une fois par tour. Cette protection s'applique à la première destruction concernée de chaque tour.
- **Autres familles compatibles :** Royaume.

### VIL-008 — Atelier Partagé

- **Type :** Action `continuous` · **Rareté :** Commune · **Attribut :** Terre.
- **Rôle :** Soutien continu : elle reste sur le terrain après son activation.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale dans une Zone Action/Piège libre ; elle reste sur le terrain.
- **Ce qu’elle fait :** Une fois par tour, lorsqu'un Équipement est attaché à un Personnage : place 1 marqueur Outil ici. Retire 2 marqueurs ; pioche 1 carte, puis défausse 1 carte.

### VIL-009 — Tablier aux Cent Poches

- **Type :** Action `equipment` · **Rareté :** Rare · **Attribut :** Terre.
- **Rôle :** Équipement : elle améliore ou protège un Personnage auquel elle est attachée.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale et choisis un Personnage légal à équiper. Elle occupe une Zone Action/Piège.
- **Ce qu’elle fait :** Équipe un Personnage Village. Il gagne 400 DEF. Une fois par tour : regarde la carte du dessus de ton deck ; si c'est un Équipement, tu peux la révéler et l'ajouter à ta main, puis place 1 carte de ta main sous le deck.

### VIL-010 — Étincelle de la Forge Ancestrale

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation Fusion : envoie depuis ton terrain au Cimetière « Forgeronne des Étincelles Bleues », « Maître Artisan des Trois Métaux » et 1 Équipement ; invoque spécialement « Forge-Ancêtre, Main du Peuple » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### VIL-011 — Mur de Banco Renforcé

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Terre.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage Village en Défense est attaqué : il gagne 1000 DEF pendant ce combat.
- **Autres familles compatibles :** Royaume.

### VIL-012 — Travail Bien Fait

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Lumière.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet doit détruire ou bannir un Équipement que tu contrôles : annule l'activation et détruis sa carte.

### VIL-013 — Grand Village des Artisans

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Terre.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Village gagnent 200 DEF. Une fois par tour, le premier Équipement que tu actives peut cibler un Personnage Village depuis ton Cimetière ; invoque d'abord ce Personnage en Défense, effets annulés, puis équipe-le.
- **Autres familles compatibles :** Royaume.

### VIL-014 — Marteau des Trois Métaux

- **Type :** Relique `equipment` · **Rareté :** Épique · **Attribut :** Feu.
- **Rôle :** Relique : carte spéciale de soutien, d’équipement ou de victoire alternative selon son texte.
- **Comment la jouer ou l’invoquer :** Active-la pendant une Phase principale en suivant exactement son texte. Vérifie si elle fonctionne comme Action, Équipement ou condition de victoire.
- **Ce qu’elle fait :** Équipe un Personnage Village. Il gagne 300 ATK/DEF pour chaque autre Équipement que tu contrôles, avec un maximum de 900. Si cette carte devrait être détruite, tu peux détruire un autre Équipement que tu contrôles à la place.
- **Autres familles compatibles :** Royaume.

### VIL-015 — Forge-Ancêtre, Main du Peuple

- **Type :** Mythique · Fusion · **Rareté :** Légendaire · **Attribut :** Esprit · **Rang/ATK/DEF :** 10 · 3600/3900.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Étincelle de la Forge Ancestrale  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoquée par « Étincelle de la Forge Ancestrale ». À son invocation : équipe-lui jusqu'à 2 Équipements de noms différents depuis ton Cimetière. Une fois par tour : envoie 1 Équipement qu'elle porte au Cimetière ; annule la destruction d'une carte que tu contrôles.
- **Autres familles compatibles :** Ancêtre.

## Famille Maquis

**Style de jeu :** gagner des PV, réutiliser les Actions et enchaîner les ressources.

### MAQ-001 — Serveur aux Sandales Rapides

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Vent · **Rang/ATK/DEF :** 1 · 600/600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** À son invocation : tu peux renvoyer 1 autre carte Maquis que tu contrôles dans ta main ; gagne 300 PV.
- **Autres familles compatibles :** Babi.

### MAQ-002 — Vendeuse d'Alloco Solaire

- **Type :** Personnage · **Rareté :** Commune · **Attribut :** Feu · **Rang/ATK/DEF :** 2 · 900/1300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Une fois par tour, si tu gagnes des PV : cible 1 Personnage Maquis ; il gagne 300 ATK ce tour.
- **Autres familles compatibles :** Babi.

### MAQ-003 — Videur au Grand Sourire

- **Type :** Personnage simple · **Rareté :** Commune · **Attribut :** Terre · **Rang/ATK/DEF :** 4 · 1800/2000.
- **Rôle :** Combattant simple : facile à comprendre, utile pour attaquer, défendre ou servir de sacrifice.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** Aucun effet.
- **Autres familles compatibles :** Babi.

### MAQ-004 — DJ du Car Rapide

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Vent · **Rang/ATK/DEF :** 4 · 1700/1500.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Invoque-la face visible en Attaque ou pose-la face cachée en Défense, sans sacrifice.
- **Ce qu’elle fait :** La première fois par tour que tu actives une Action Maquis, cette carte gagne 400 ATK jusqu'à la fin du tour.
- **Autres familles compatibles :** Babi.

### MAQ-005 — Cuisinière de Minuit

- **Type :** Personnage · **Rareté :** Rare · **Attribut :** Feu · **Rang/ATK/DEF :** 5 · 2100/2300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** À son invocation : révèle les 3 cartes du dessus de ton deck ; ajoute 1 Action Maquis révélée à ta main et replace les autres sous le deck dans l'ordre de ton choix.
- **Autres familles compatibles :** Village.

### MAQ-006 — Patron du Coin Lumineux

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Lumière · **Rang/ATK/DEF :** 6 · 2500/2300.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 1 Personnage que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour, après la résolution d'une Action Maquis : gagne 400 PV. Si tu as gagné au moins 800 PV ce tour, pioche 1 carte puis défausse 1 carte.
- **Autres familles compatibles :** Babi.

### MAQ-007 — Légende du Quartier Sans Sommeil

- **Type :** Personnage · **Rareté :** Épique · **Attribut :** Lumière · **Rang/ATK/DEF :** 7 · 2800/2600.
- **Rôle :** Combattant à effet : il occupe une Zone Personnage et apporte un avantage en plus de ses ATK/DEF.
- **Comment la jouer ou l’invoquer :** Pour une invocation ou pose normale, sacrifie 2 Personnages que tu contrôles.
- **Ce qu’elle fait :** Une fois par tour : défausse 1 Action ; cette carte peut effectuer une seconde attaque sur un Personnage ce tour. Les dégâts de combat infligés lors de cette seconde attaque sont divisés par deux, arrondis au supérieur.
- **Autres familles compatibles :** Babi.

### MAQ-008 — Tournée Générale

- **Type :** Action `normal` · **Rareté :** Commune · **Attribut :** Lumière.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Chaque joueur gagne 500 PV. Tu pioches ensuite 1 carte puis défausses 1 carte.

### MAQ-009 — Commande Express

- **Type :** Action `quick` · **Rareté :** Rare · **Attribut :** Vent.
- **Rôle :** Réaction rapide : elle sert à modifier une situation ou surprendre l’adversaire.
- **Comment la jouer ou l’invoquer :** Pendant ton tour, active-la depuis la main. Pendant le tour adverse, elle doit normalement avoir été posée depuis un tour.
- **Ce qu’elle fait :** Cible 1 Personnage Maquis ; renvoie-le dans ta main, puis invoque spécialement depuis ta main 1 Personnage Maquis de rang inférieur.
- **Autres familles compatibles :** Babi.

### MAQ-010 — Banquet des Étoiles Urbaines

- **Type :** Action `normal` · **Rareté :** Épique · **Attribut :** Esprit.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Invocation ancestrale : défausse 2 Actions Maquis de noms différents et sacrifie des Personnages Maquis dont le total des rangs est au moins 8 ; invoque spécialement « Grand Maquisard Cosmique » depuis ta Réserve des Mythiques.
- **Autres familles compatibles :** Ancêtre.

### MAQ-011 — Plateau Très Glissant

- **Type :** Piège `normal` · **Rareté :** Commune · **Attribut :** Eau.
- **Rôle :** Piège défensif : il est posé face cachée et surprend l’adversaire lorsque sa condition arrive.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un Personnage adverse déclare une attaque : annule l'attaque et renvoie dans ta main 1 Personnage Maquis que tu contrôles.
- **Autres familles compatibles :** Lagune.

### MAQ-012 — Addition Contestée

- **Type :** Piège `counter` · **Rareté :** Rare · **Attribut :** Ombre.
- **Rôle :** Contre-Piège : réponse très rapide destinée à annuler une action adverse.
- **Comment la jouer ou l’invoquer :** Pose-la face cachée dans une Zone Action/Piège libre. Elle ne peut normalement pas être activée le tour où elle est posée.
- **Ce qu’elle fait :** Lorsqu'un effet adverse ferait perdre des PV en dehors du combat : défausse 1 carte ; annule cet effet et gagne 300 PV.
- **Autres familles compatibles :** Babi.

### MAQ-013 — Maquis des Mille Saveurs

- **Type :** Terrain · **Rareté :** Rare · **Attribut :** Feu.
- **Rôle :** Terrain : il modifie durablement le duel et soutient surtout sa famille.
- **Comment la jouer ou l’invoquer :** Active-la dans ta Zone Terrain. Si tu contrôles déjà un Terrain, l’ancien va au Cimetière sans être considéré comme détruit.
- **Ce qu’elle fait :** Les Personnages Maquis gagnent 200 ATK/DEF. Une fois par tour, lorsqu'un joueur gagne des PV par l'effet d'une autre carte, le propriétaire de ce Terrain gagne 200 PV. Ce gain ne peut pas déclencher cet effet.
- **Autres familles compatibles :** Babi.

### MAQ-014 — Marmite Qui Ne Se Vide Jamais

- **Type :** Relique `action` · **Rareté :** Épique · **Attribut :** Feu.
- **Rôle :** Action immédiate : elle produit son effet puis va normalement au Cimetière.
- **Comment la jouer ou l’invoquer :** Active-la depuis la main pendant une Phase principale, dans une Zone Action/Piège libre. Après sa résolution, elle va au Cimetière.
- **Ce qu’elle fait :** Place cette Relique face visible dans une Zone Action/Piège libre avec 3 marqueurs Portion. Une fois par tour : retire 1 marqueur ; gagne 600 PV. Sans marqueur, envoie cette carte au Cimetière et pioche 1 carte.
- **Autres familles compatibles :** Village.

### MAQ-015 — Grand Maquisard Cosmique

- **Type :** Mythique · Ancestrale · **Rareté :** Légendaire · **Attribut :** Lumière · **Rang/ATK/DEF :** 9 · 3400/3100.
- **Rôle :** Carte maîtresse : elle sert généralement à terminer le duel ou à reprendre un gros avantage.
- **Comment la jouer ou l’invoquer :** Garde-la dans la Réserve des Mythiques. Invoque-la spécialement grâce à «  Banquet des Étoiles Urbaines  » après avoir payé les matériaux ou sacrifices indiqués.
- **Ce qu’elle fait :** Doit d'abord être invoqué par « Banquet des Étoiles Urbaines ». À son invocation : gagne 1000 PV, puis ajoute à ta main 1 Action Maquis depuis ton Cimetière. Une fois par tour, après la résolution de ta deuxième Action du tour : détruis 1 carte adverse face visible.
- **Autres familles compatibles :** Babi.

## Conseils pour commencer

- Commence avec des Personnages de rang 1 à 4 : ils ne demandent aucun sacrifice.
- Ne joue pas toutes tes cartes immédiatement : garde une Action rapide ou un Piège pour répondre.
- Vérifie toujours tes zones libres avant de payer un coût.
- Un gros Personnage n’est pas toujours meilleur : un petit Personnage avec un bon effet peut préparer une Mythique.
- Lis d’abord la condition de la Mythique, puis construis ton plan autour de sa carte déclencheuse.
