# MystiCartes V2 — Game Design Document officiel (v1.1 — verrouillé)

*Ce document fait foi. Toute implémentation (schéma, moteur, IA, contenu des cartes) doit s'y référer. Version verrouillée après relecture complète — plus d'ambiguïté ouverte pour le scope du MVP V2.*

## 1. Vue d'ensemble

MystiCartes oppose deux **Duelistes**. Chacun construit un deck et affronte l'autre en duel de cartes, avec zones de terrain, combat entre Personnages (ATK/DEF), Pièges, et invocations spéciales de cartes puissantes appelées **Mythiques** (renommé depuis "Légendes" pour ne pas entrer en collision avec la rareté "Légendaire").

## 2. Points de Vie et victoire

- Chaque joueur commence avec **8000 PV**. Pas de plafond maximum, jamais sous 0.
- Victoire immédiate si : PV adverses à 0 · adversaire doit piocher une carte manquante (défaite immédiate) · condition explicite d'une carte · abandon adverse.
- **Victoire pendant une Chaîne** : la victoire est vérifiée après chaque effet atomique et chaque combat. Dès qu'elle est constatée, la Chaîne s'arrête immédiatement. Si le même effet met les deux joueurs à 0 simultanément : **match nul**.

## 3. Rareté vs Catégorie de carte

- **Rareté** (`rarity`) : `commune`, `rare`, `épique`, `légendaire`.
- **Catégorie** (`card_category`) : `personnage`, `action`, `piège`, `terrain`, `relique`, `mythique`. Deux notions indépendantes, jamais confondues dans le schéma ou l'UI.

## 4. Construction du deck

- **Deck principal : exactement 40 cartes.**
- **3 exemplaires maximum par nom**, comptés sur l'ensemble **deck principal + réserve latérale + Réserve des Mythiques combinés**.
- **Réserve latérale (side deck)** : 0 à 15 cartes, hors scope du MVP (nécessite le format Bo3, non prioritaire).
- **Réserve des Mythiques** : jusqu'à 15 cartes de catégorie Mythique, séparée du deck principal.
- Liste interdits/limités : hors scope MVP (un seul set au lancement).

## 5. Catégories de cartes

### 5.1 Personnage

Champs : nom, famille principale (+ familles secondaires optionnelles), rang, ATK, DEF, attribut, effet éventuel.

**Rang (1-10)** — sacrifices requis pour l'invocation normale :

- **1-4** : aucun sacrifice.
- **5-6** : 1 sacrifice.
- **7-8** : 2 sacrifices.
- **9-10** : **réservé exclusivement aux Mythiques**, jamais invocable normalement.

**Droit d'attaque** : un Personnage peut attaquer le tour de son invocation (pas de "maladie d'invocation" pour simplifier le MVP), sauf lors du premier tour du joueur qui commence, ou indication contraire d'une carte. Ce choix pourra être révisé après tests d'équilibrage.

### 5.2 Action

`card_subtype` : `normal` (Phase principale, va au Cimetière après résolution) · `quick` (jouable pendant son propre tour depuis la main ; pendant le tour adverse uniquement si posée au préalable, jamais le tour de sa pose) · `continuous` (reste sur le terrain) · `equipment` (attachée à un Personnage, occupe une zone Action/Piège).

### 5.3 Piège / Contre-Piège

`card_subtype` : `normal` (posé face cachée, inactivable le tour de sa pose) · `continuous` · `counter` (catégorie `piège`, sous-type `counter` — la réponse la plus rapide, normalement seule une autre Vitesse 3 peut y répondre).

### 5.4 Terrain

Une seule carte Terrain active par joueur. En jouer une nouvelle envoie l'ancienne au Cimetière (**non considérée comme détruite** — distinction importante pour les effets liés à la destruction).

### 5.5 Relique

Chaque Relique a un `relic_mode` explicite (fonctionnement Action, Équipement, ou condition de victoire alternative) définissant ses zones et règles d'activation propres, carte par carte.

### 5.6 Mythique

Carte combattante à part entière (rang, ATK, DEF, attribut, familles) — **toutes les Mythiques du lancement sont de rang 9 ou 10**, jamais invocables normalement. Accessibles via :

- **Invocation spéciale (Fusion)** : combine des Personnages précis (envoyés au Cimetière).
- **Invocation ancestrale (Rituel)** : Action ancestrale + Personnage précis, ou sacrifices dont le total de Rangs atteint un seuil.

## 6. Familles (10 au lancement)

Babi, Royaume, Ancêtre, Masque, Dozo, Forêt, Lagune, Savane, Village, Maquis.

Chaque carte a une **famille principale** (15 cartes par famille principale = 150 au total) et peut avoir des **familles secondaires** optionnelles sans que ça change le total de 150.

## 7. Attributs

Feu 🔥, Eau 💧, Nature 🌿, Vent 🌬, Lumière ☀️, Ombre 🌑, Terre 🪨, Esprit ✨.

## 8. Zones de jeu (par joueur)

5 Zones Personnage · 5 Zones Action/Piège · 1 Zone Terrain · 1 Deck · 1 Cimetière · 1 Zone Bannissement · 1 Réserve des Mythiques.

**Zone pleine** : impossible d'invoquer/poser sans zone libre. Une Action normale occupe temporairement une zone pendant son activation et sa résolution.

**Information cachée** : main et deck secrets (nombre de cartes public) · identité d'une carte face cachée visible uniquement par son contrôleur · Cimetière et Bannissement publics.

## 9. Déroulement du tour

**Phases :** Pioche (1 carte, sauf 1er tour du joueur qui commence) → Préparation → Phase principale 1 → Phase de Combat → Phase principale 2 → Fin de tour.

- **Main de départ : 5 cartes, sans mulligan.** Premier joueur tiré au sort.
- **Limite de main : 6 cartes en fin de tour.** Ordre : résoudre d'abord tous les effets de fin de tour, puis défausser jusqu'à 6 ; recommencer si un effet déclenché fait remonter au-dessus de 6.
- **Une Invocation normale OU une Pose normale gratuite par tour** — cette limite concerne **uniquement les Personnages** (invoquer face visible en Attaque, ou poser face cachée en Défense). Poser une Action/Piège ne consomme pas cette permission.
- Le joueur qui commence ne pioche pas et ne peut pas attaquer à son 1er tour, mais peut invoquer/poser/activer normalement.

## 10. Priorité et Chaîne

- Après une activation, l'**adversaire reçoit la première priorité de réponse**, puis les joueurs alternent. **Deux passes successives** déclenchent la résolution de toute la Chaîne, résolue en ordre inverse (dernière carte activée = résolue en premier).
- **Simplification MVP** (pour éviter de reproduire toutes les subtilités d'un timing façon Yu-Gi-Oh) : réponses autorisées après invocation, pose, activation d'effet et déclaration d'attaque · aucune nouvelle Chaîne pendant le calcul ATK/DEF, sauf carte l'autorisant explicitement · aucune activation ajoutée pendant la résolution d'une Chaîne.
- **Vitesses** : Vitesse 1 (Actions normales, effets ordinaires/retournement — non activables en réponse) · Vitesse 2 (Actions rapides, Pièges normaux/continus, effets rapides — répondent aux vitesses 1 et 2) · Vitesse 3 (Contre-Pièges).

## 11. Combat

- Position Attaque (verticale, ATK) ou Défense (horizontale, DEF). Changement manuel : une fois par tour, jamais le tour d'invocation/pose, jamais après avoir attaqué.
- **Attaque directe** si l'adversaire ne contrôle aucun Personnage : dégâts = ATK de l'attaquant.
- **ATK vs ATK** : le plus faible détruit, son contrôleur perd la différence en PV. Égalité = les deux détruits, aucun dégât.
- **ATK vs DEF** : ATK > DEF → défenseur détruit, aucun PV perdu par le défenseur. ATK < DEF → rien détruit, l'attaquant perd la différence en PV. Égalité = rien ne se passe.
- Personnage face cachée en Défense attaqué : retourné face visible avant calcul des dégâts, effets de retournement déclenchés.
- **Attaque interrompue** (la cible quitte le terrain avant le calcul) : l'attaque se termine sans redirection et sans attaque directe de remplacement.
- Une seule attaque par Personnage et par tour, sauf effet contraire explicite.

## 12. Cimetière, bannissement, jetons, marqueurs, cibles

- Cimetière public, ordre non modifiable sans raison. Bannissement distinct du Cimetière, face visible.
- Défausser (main → Cimetière) ≠ détruire (terrain → Cimetière). "Ne peut pas être détruit" ne protège ni du bannissement, ni du sacrifice, ni du renvoi en main/deck.
- **Jetons** : peuvent combattre et être sacrifiés sauf restriction ; jamais face cachée ; disparaissent en quittant le terrain (jamais en main/deck/Cimetière/bannissement).
- **Marqueurs** : restent sur une carte jusqu'à suppression par effet ou départ de la carte.
- **Ciblage** : une carte ne cible que si son texte le dit explicitement. **Cible devenue illégale** : vérifiée à l'activation et à la résolution ; si invalide, l'effet concerné échoue sans nouvelle cible, mais le coût reste payé.
- Effet obligatoire = résolu automatiquement. Effet optionnel ("tu peux") = au choix du joueur.
- **Arrondi : à l'entier supérieur**, sauf indication contraire d'une carte.

## 13. Format de match

**Match unique par défaut** (pas de Bo3 pour le MVP — adapté au mobile/solo). Bo3 + réserve latérale : hors scope MVP, prévu pour une future version compétitive. Durée cible : 15-20 minutes par match.

## 14. Hors scope MVP V2

Réserve latérale et changements entre manches · liste interdits/limités · PvP (le MVP V2 reste solo vs IA).

## 15. Prochaines étapes

1. ✅ GDD verrouillé — référence officielle à partir de maintenant.
2. Concevoir les 150 cartes selon cette structure (avec moi, avant tout codage de contenu).
3. Nouveau schéma Supabase (Phase 3).
4. Nouveau moteur de jeu (Phase 4).
5. Nouvelle UI de combat à zones (Phase 5).
6. IA adaptée (Phase 7).
