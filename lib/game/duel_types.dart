/// Les deux participants du duel solo V2.
enum DuelParticipant { player, ai }

/// Catégories de cartes nécessaires au moteur local V2.
enum CardCategory { character, action, trap, terrain, relic, mythic }

/// Position de combat d'une carte présente dans une zone de Personnage.
enum BattlePosition { attack, defense }

/// Phases canoniques d'un tour MystiCartes V2.
enum DuelPhase { draw, preparation, main1, battle, main2, end }

/// Cause actuellement connue de fin immédiate d'un duel.
enum DuelEndReason { deckOut, lifePointsDepleted, cardEffect }
