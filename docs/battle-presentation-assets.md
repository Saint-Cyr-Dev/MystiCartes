# Présentation du combat et chargement — septembre 2026

Cette étape ne change aucune règle dans `lib/game/`.

## Animations et pause

- Carte jouée : 2 secondes ; source d’effet : 1,8 seconde ; attaque : 1,6 seconde.
- Entrée sur 15 % de la durée, maintien immobile/lisible jusqu’à 78 %, puis sortie.
- Paramètres remplace la réinitialisation directe : pause, Reprendre, rythme Normal / Plus lisible (×1,5), Recommencer avec confirmation.
- `BattlePresentationScheduler` conserve le temps restant des délais de présentation et de l’attente IA. Un redémarrage ou la fermeture annule les anciens délais.
- `BattlePausableAnimation` arrête réellement sa progression pendant la pause. Les grandes cartes et les effets superposés reprennent sans saut.
- Le moteur détermine immédiatement la victoire ; seul l’affichage du résultat attend que les dernières grandes cartes soient montrées.
- Le réglage de durée reste local à l’écran de combat, sans nouvelle table ni dépendance.

## Fonds générés

Outil : ImageGen intégré, via le skill `imagegen`, sans API externe ni clé. Les sources originales sont conservées. Tous les fichiers consommés sont dans `assets/images/backgrounds/` et embarqués par `pubspec.yaml`.

| Fichier | Dimensions réellement produites | Usage |
| --- | --- | --- |
| `battle-portrait-v2.png` | 887 × 1774 | téléphone portrait |
| `battle-square-v2.png` | 1254 × 1254 | carré / tablette |
| `battle-landscape-v2.png` | 1536 × 1024 | ordinateur / paysage |
| `battle-ultrawide-v2.png` | 1881 × 836 | écran très large |
| `loading-portrait-v2.png` | 887 × 1774 | chargement portrait |
| `loading-landscape-v2.png` | 1659 × 948 | chargement paysage |

ImageGen a respecté les proportions demandées mais produit les dimensions ci-dessus, différentes des dimensions indicatives du prompt. Aucune image n’est artificiellement étirée. `BattleBackdrop` choisit le ratio le plus proche (distance logarithmique) et emploie `BoxFit.cover`. Un léger recadrage est donc possible sur les ratios intermédiaires, sans bandes vides ni déformation. Le fond occupe tout le viewport, y compris sous l’en-tête ; le plateau conserve son ajustement indépendant.

## Écran de chargement

`BattleLaunchScreen` conserve les vrais chargements progression puis deck. `BattleLoadingView` présente leur état, une barre indéterminée (aucun faux pourcentage), cinq conseils avec flèches et glissement, et les icônes des dix familles. La composition reprend l’image de référence fournie par Junior, mais utilise le diamant violet du menu existant. L’illustration ne contient aucun texte ni contrôle : ces éléments restent de vrais widgets.

Un court fondu de lancement s’effectue en parallèle du chargement. Le duel ne s’ouvre jamais avant réception du deck. Retour annule la navigation différée ; les erreurs permettent de réessayer. Le mode local passe aussi par ce chargement, sans Supabase.

## Prompts de génération

### Fonds de combat — base commune

Référence : `assets/images/backgrounds/battle-board.png`.

> Use case: stylized-concept. Asset type: MystiCartes fullscreen card-duel background. Image 1 is a visual reference of the same arena. Create a polished matching composition, not a UI screenshot. Preserve the violet/gold mystical stone terrace, engraved arena floor, distant contemporary African fantasy city with afrofuturistic towers, warm lanterns, tropical plants and dark starry purple atmosphere. Perspective slightly elevated. Large quiet empty floor for readable cards overlaid by the app, ornament and architecture mostly at outer edges. No characters, no cards, no writing, no interface, no borders, no black letterboxing. Full bleed.

Variantes ajoutées à cette base :

- Portrait : `Output composition: 1024x2048, tall portrait 1:2. Recompose vertically for a narrow phone: floor extends over most of the frame, skyline in top quarter; central circular motif near middle.`
- Carré : `Output composition: 1536x1536, square 1:1. Recompose for a tablet: wide open central stone floor, terrace and city towards top, side lanterns.`
- Paysage : `Output composition: 1536x1024, landscape 3:2. Recompose for desktop: broad playable circular floor occupying lower three quarters, city above.`

### Combat ultralarge

Référence : `battle-landscape-v2.png`.

> Use case: stylized-concept. Asset type: MystiCartes fullscreen card-duel background. Image 1 is the matching arena reference. Create ultra-wide panoramic version 2304x1024, aspect ratio9:4. Preserve violet and gold mystical stone terrace, engraved arena floor with small central purple gem, distant contemporary African fantasy city and afrofuturistic towers, warm lanterns and tropical plants. Slightly elevated view. Extend architecture and city at both edges, broad empty quiet arena floor for cards to be overlaid by the app. Full bleed panoramic composition, no letterboxing. No text, no characters, no cards, no UI, no borders. Same detailed illustration style and night atmosphere as reference.

### Chargement portrait

Référence utilisateur : `Écran de chargement MystiCartes fantastique.png`.

> Use case: stylized-concept. Asset type: MystiCartes loading-screen BACKGROUND ART ONLY. Image 1 is user's exact composition reference. Recreate the illustrated environment and two opposing characters, with all lettering, logo, cards at top, progress bar, ornaments belonging to UI, numbers and buttons COMPLETELY REMOVED. Vertical 1024x2048 full-bleed composition. Majestic African king gold crown on left facing right, African braided mystical woman blue magical flame on right facing left, both in lower two thirds, framing the sunset Abidjan-inspired lagoon city with cable bridge. Dark navy and violet clouds upper third is EMPTY calm space where app will draw its own purple diamond logo. Original scene's gold sunset and blue magic, deep dark corners and bottom for app's loading controls. Detailed premium fantasy painting, cultural clothing and contemporary urban landscape, faithful to reference. No text, no watermarks, no graphical UI, no logo. Characters large and readable at edges, middle open for status overlay.

### Chargement paysage

Référence : `loading-portrait-v2.png`.

> Use case: stylized-concept. MystiCartes game loading BACKGROUND ART only. Image1 is the portrait art to adapt; preserve same identities, clothing, palette and painted detailed style. Recompose as landscape 1792x1024, wide16:9. African king in gold crown large at far left facing right, braided African sorceress holding blue magical fire far right facing left. Faces towards outer quarters, wide open middle showing the golden sunset on the lagoon and contemporary Abidjan-inspired cable bridge and fantasy city. Upper middle dark purple storm clouds with blank space for application's logo and loading UI. Lower middle dark quiet river for overlays. Full bleed, no text, no logo, no playing cards, no progress bar or any interface. Do not merely crop portrait, recompose for wide screens.

## Vérification visuelle reproductible

`flutter test tool/capture_battle_ui_test.dart --no-pub` produit les captures réelles dans `build/visual-review/`. Sous Windows, cet outil de QA charge les polices système pour éviter la police de test Ahem ; il ne modifie pas les polices de l’application.
