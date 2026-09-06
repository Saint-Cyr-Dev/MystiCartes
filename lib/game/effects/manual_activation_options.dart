import '../battle_state.dart';
import '../card.dart';
import '../duel_engine.dart';
import '../duel_types.dart';
import '../player.dart';

/// Contexte factuel de la fenêtre courante. Il ne contient aucune décision UI.
final class ManualActivationContext {
  const ManualActivationContext({
    this.attack,
    this.destroyedCharacterRank,
    this.destroyedWasForest = false,
    this.summonedOpponentInstanceId,
    this.opponentEffectWouldLoseLife = false,
    this.events = const [],
  });

  final AttackDeclaration? attack;
  final int? destroyedCharacterRank;
  final bool destroyedWasForest;
  final String? summonedOpponentInstanceId;
  final bool opponentEffectWouldLoseLife;
  final List<PendingDuelEvent> events;

  T? firstEvent<T extends PendingDuelEvent>() {
    for (final event in events) {
      if (event is T) return event;
    }
    return null;
  }

  ManualActivationContext withAdditionalEvents(
    Iterable<PendingDuelEvent> additional,
  ) {
    return ManualActivationContext(
      attack: attack,
      destroyedCharacterRank: destroyedCharacterRank,
      destroyedWasForest: destroyedWasForest,
      summonedOpponentInstanceId: summonedOpponentInstanceId,
      opponentEffectWouldLoseLife: opponentEffectWouldLoseLife,
      events: List.unmodifiable([...events, ...additional]),
    );
  }
}

/// Activation entièrement préparée par le moteur : cible et coût sont déjà
/// encodés dans [link]. L'interface ne connaît aucun code de carte.
final class ManualActivationOption {
  const ManualActivationOption({
    required this.source,
    required this.link,
    required this.description,
  });

  final CardInstance source;
  final ChainLink link;
  final String description;
}

typedef ManualActivationBuilder = Iterable<ManualActivationOption> Function(
  ManualActivationRequest request,
);

/// Immutable view supplied to an effect when it enumerates targets and costs.
/// Builders propose options only; the engine subsequently validates each one.
final class ManualActivationRequest {
  const ManualActivationRequest(
      {required this.state,
      required this.participant,
      required this.source,
      required this.context});
  final DuelState state;
  final DuelParticipant participant;
  final CardInstance source;
  final ManualActivationContext context;
  PlayerFieldState get own => field(state, participant);
  PlayerFieldState get enemy => field(state, opponent(participant));
  List<CardInstance> get ownCharacters =>
      own.characterZones.whereType<CardInstance>().toList();
  List<CardInstance> get enemyCharacters =>
      enemy.characterZones.whereType<CardInstance>().toList();
  List<CardInstance> get allCharacters =>
      [...ownCharacters, ...enemyCharacters];
  ChainLink? get last => state.chain.links.lastOrNull;
  AttackDeclaration? get attack => context.attack;
  ManualActivationOption option({
    ChainTarget? target,
    Map<String, Object?> payload = const {},
    String description = 'Activer',
    String suffix = '0',
  }) {
    final attack = this.attack;
    final attacker =
        attack == null ? null : findCard(state, attack.attackerInstanceId);
    final strategicPayload = <String, Object?>{
      ...payload,
      'createsAdvantage': true,
      if (attack != null) 'preventsAttack': true,
      if (attacker?.effectiveAtk != null)
        'incomingDamage': attacker!.effectiveAtk,
    };
    final speed =
        source.category == CardCategory.trap && source.subtype == 'counter'
            ? ChainSpeed.speed3
            : source.category == CardCategory.trap || source.subtype == 'quick'
                ? ChainSpeed.speed2
                : ChainSpeed.speed1;
    return ManualActivationOption(
      source: source,
      description: description,
      link: ChainLink(
        linkId:
            'manual:${state.turnNumber}:${state.chain.links.length}:${source.instanceId}:$suffix',
        effectKey: source.effectKey!,
        activatingPlayer: participant,
        speed: speed,
        sourceCardInstanceId: source.instanceId,
        sourceCardCode: source.cardCode,
        target: target,
        payload: strategicPayload,
      ),
    );
  }

  PlayerFieldState field(DuelState state, DuelParticipant participant) =>
      participant == DuelParticipant.player ? state.playerField : state.aiField;

  DuelParticipant opponent(DuelParticipant participant) =>
      participant == DuelParticipant.player
          ? DuelParticipant.ai
          : DuelParticipant.player;

  CardInstance? sourceCard(DuelState state, ChainLink? link) =>
      link?.sourceCardInstanceId == null
          ? null
          : findCard(state, link!.sourceCardInstanceId!);

  CardInstance? targetCard(DuelState state, ChainLink? link) =>
      link?.target == null
          ? null
          : findCard(state, link!.target!.cardInstanceId);

  CardInstance? findCard(DuelState state, String instanceId) {
    for (final field in [state.playerField, state.aiField]) {
      for (final card in [
        ...field.hand,
        ...field.graveyard,
        ...field.banished,
        ...field.mythicReserve,
        ...field.characterZones.whereType<CardInstance>(),
        ...field.actionTrapZones.whereType<CardInstance>(),
        if (field.terrainZone case final CardInstance terrain) terrain,
      ]) {
        if (card.instanceId == instanceId) return card;
      }
    }
    return null;
  }
}
