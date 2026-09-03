import 'card.dart';
import 'duel_types.dart';

const Object _notProvided = Object();

/// Ensemble des zones appartenant à un participant.
///
/// Les listes sont exposées en lecture seule. Une modification produit un
/// nouvel état avec [copyWith], ce qui rend les instantanés de duel simples à
/// comparer et à tester.
final class PlayerFieldState {
  PlayerFieldState({
    required this.participant,
    required List<FieldCardInstance?> characterZones,
    required List<CardInstance?> actionTrapZones,
    required this.terrainZone,
    required List<CardInstance> deck,
    required List<CardInstance> hand,
    required List<CardInstance> graveyard,
    required List<CardInstance> banished,
    required List<CardInstance> mythicReserve,
    Set<String> revealedCardInstanceIds = const {},
  })  : assert(characterZones.length == characterZoneCount),
        assert(actionTrapZones.length == actionTrapZoneCount),
        characterZones = List.unmodifiable(characterZones),
        actionTrapZones = List.unmodifiable(actionTrapZones),
        deck = List.unmodifiable(deck),
        hand = List.unmodifiable(hand),
        graveyard = List.unmodifiable(graveyard),
        banished = List.unmodifiable(banished),
        mythicReserve = List.unmodifiable(mythicReserve),
        revealedCardInstanceIds = Set.unmodifiable(revealedCardInstanceIds);

  static const int characterZoneCount = 5;
  static const int actionTrapZoneCount = 5;

  factory PlayerFieldState.empty({
    required DuelParticipant participant,
    List<CardInstance> deck = const [],
    List<CardInstance> mythicReserve = const [],
  }) {
    return PlayerFieldState(
      participant: participant,
      characterZones: List<FieldCardInstance?>.filled(
        characterZoneCount,
        null,
      ),
      actionTrapZones: List<CardInstance?>.filled(
        actionTrapZoneCount,
        null,
      ),
      terrainZone: null,
      deck: deck,
      hand: const [],
      graveyard: const [],
      banished: const [],
      mythicReserve: mythicReserve,
    );
  }

  final DuelParticipant participant;

  /// Accepte une carte du catalogue ou un [TokenInstance].
  final List<FieldCardInstance?> characterZones;

  /// Les jetons ne peuvent pas occuper ces zones.
  final List<CardInstance?> actionTrapZones;
  final CardInstance? terrainZone;

  /// Collections ordonnées composées exclusivement de cartes du catalogue.
  final List<CardInstance> deck;
  final List<CardInstance> hand;
  final List<CardInstance> graveyard;
  final List<CardInstance> banished;
  final List<CardInstance> mythicReserve;

  /// Cartes face cachée dont ce participant connaît actuellement l'identité.
  final Set<String> revealedCardInstanceIds;

  PlayerFieldState copyWith({
    DuelParticipant? participant,
    List<FieldCardInstance?>? characterZones,
    List<CardInstance?>? actionTrapZones,
    Object? terrainZone = _notProvided,
    List<CardInstance>? deck,
    List<CardInstance>? hand,
    List<CardInstance>? graveyard,
    List<CardInstance>? banished,
    List<CardInstance>? mythicReserve,
    Set<String>? revealedCardInstanceIds,
  }) {
    return PlayerFieldState(
      participant: participant ?? this.participant,
      characterZones: characterZones ?? this.characterZones,
      actionTrapZones: actionTrapZones ?? this.actionTrapZones,
      terrainZone: identical(terrainZone, _notProvided)
          ? this.terrainZone
          : terrainZone as CardInstance?,
      deck: deck ?? this.deck,
      hand: hand ?? this.hand,
      graveyard: graveyard ?? this.graveyard,
      banished: banished ?? this.banished,
      mythicReserve: mythicReserve ?? this.mythicReserve,
      revealedCardInstanceIds:
          revealedCardInstanceIds ?? this.revealedCardInstanceIds,
    );
  }
}
