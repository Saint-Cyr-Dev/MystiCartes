import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/ai/ai_strategy.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/ancetre_effects.dart';
import 'package:mysticartes/game/effects/babi_effects.dart';
import 'package:mysticartes/game/effects/dozo_effects.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/effects/foret_effects.dart';
import 'package:mysticartes/game/effects/lagune_effects.dart';
import 'package:mysticartes/game/effects/manual_activation.dart';
import 'package:mysticartes/game/effects/maquis_effects.dart';
import 'package:mysticartes/game/effects/masque_effects.dart';
import 'package:mysticartes/game/effects/royaume_effects.dart';
import 'package:mysticartes/game/effects/savane_effects.dart';
import 'package:mysticartes/game/effects/village_effects.dart';
import 'package:mysticartes/game/player.dart';

const _keys = <String, String>{
  'ROY-009': RoyaumeEffectKeys.roy009,
  'ROY-011': RoyaumeEffectKeys.roy011,
  'ROY-012': RoyaumeEffectKeys.roy012,
  'ANC-009': AncetreEffectKeys.anc009,
  'ANC-011': AncetreEffectKeys.anc011,
  'ANC-012': AncetreEffectKeys.anc012,
  'MAS-008': MasqueEffectKeys.mas008,
  'MAS-011': MasqueEffectKeys.mas011,
  'MAS-012': MasqueEffectKeys.mas012,
  'DOZ-009': DozoEffectKeys.doz009,
  'DOZ-011': DozoEffectKeys.doz011,
  'DOZ-012': DozoEffectKeys.doz012,
  'FOR-008': ForetEffectKeys.for008,
  'FOR-011': ForetEffectKeys.for011,
  'FOR-012': ForetEffectKeys.for012,
  'LAG-008': LaguneEffectKeys.lag008,
  'LAG-011': LaguneEffectKeys.lag011,
  'LAG-012': LaguneEffectKeys.lag012,
  'SAV-009': SavaneEffectKeys.sav009,
  'SAV-011': SavaneEffectKeys.sav011,
  'SAV-012': SavaneEffectKeys.sav012,
  // Village ne possède aucune Action quick dans le catalogue V2 : VIL-009
  // est son activation manuelle d'Équipement équivalente pour cette matrice.
  'VIL-009': VillageEffectKeys.vil009,
  'VIL-011': VillageEffectKeys.vil011,
  'VIL-012': VillageEffectKeys.vil012,
  'MAQ-009': MaquisEffectKeys.maq009,
  'MAQ-011': MaquisEffectKeys.maq011,
  'MAQ-012': MaquisEffectKeys.maq012,
};

final class _Scenario {
  const _Scenario(this.state, [this.context = const ManualActivationContext()]);

  final DuelState state;
  final ManualActivationContext context;
}

CardInstance _card(
  String code, {
  required String id,
  DuelParticipant owner = DuelParticipant.player,
  CardCategory category = CardCategory.character,
  String? subtype,
  String? family,
  int? rank = 4,
  int atk = 1800,
  int def = 1600,
  bool faceUp = true,
  BattlePosition? position = BattlePosition.attack,
  int zoneIndex = 0,
  Map<String, int> counters = const {},
  Map<String, Object?> runtimeData = const {},
  String? effectKey,
}) =>
    CardInstance(
      instanceId: id,
      cardId: 'card-$id',
      cardCode: code,
      cardRevision: 1,
      category: category,
      subtype: subtype,
      rank: category == CardCategory.character ? rank : null,
      atk: category == CardCategory.character ? atk : null,
      def: category == CardCategory.character ? def : null,
      primaryFamily: family,
      effectKey: effectKey ?? _keys[code],
      owner: owner,
      controller: owner,
      faceUp: faceUp,
      position: category == CardCategory.character ? position : null,
      zoneIndex: zoneIndex,
      counters: counters,
      runtimeData: runtimeData,
    );

PlayerFieldState _field({
  required DuelParticipant participant,
  List<CardInstance> hand = const [],
  List<CardInstance?> characters = const [],
  List<CardInstance?> backrow = const [],
  List<CardInstance> graveyard = const [],
}) =>
    PlayerFieldState.empty(participant: participant, deck: const []).copyWith(
      hand: hand,
      characterZones: [
        ...characters,
        ...List<CardInstance?>.filled(5 - characters.length, null)
      ],
      actionTrapZones: [
        ...backrow,
        ...List<CardInstance?>.filled(5 - backrow.length, null)
      ],
      graveyard: graveyard,
    );

CardInstance _source(String code) {
  final isAction = code.endsWith('008') || code.endsWith('009');
  final continuous = code == 'FOR-012' || code == 'SAV-012';
  return _card(
    code,
    id: 'source-$code',
    category: isAction ? CardCategory.action : CardCategory.trap,
    subtype: code == 'VIL-009'
        ? 'equipment'
        : isAction
            ? 'quick'
            : continuous
                ? 'continuous'
                : code.endsWith('012')
                    ? 'counter'
                    : 'normal',
    faceUp: false,
    position: null,
    runtimeData: isAction ? const {} : const {CardRuntimeKeys.setOnTurn: 1},
  );
}

ChainState _responseChain(ChainLink link) => ChainState(
      links: [link],
      window: ResponseWindowType.effectActivation,
      priorityPlayer: DuelParticipant.player,
    );

ChainLink _enemyLink({
  String id = 'enemy-link',
  String sourceId = 'enemy-source',
  ChainTarget? target,
  Map<String, Object?> payload = const {},
}) =>
    ChainLink(
      linkId: id,
      effectKey: 'test-effect',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed2,
      sourceCardInstanceId: sourceId,
      sourceCardCode: 'TEST',
      target: target,
      payload: payload,
    );

final class _TypedLifeLossEffect extends ChainEffectDefinition {
  const _TypedLifeLossEffect();

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) => [
        LifePointLossPending(
          sourceLinkId: link.linkId,
          participant: DuelParticipant.player,
          amount: 600,
        ),
      ];

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

final class _TypedDestructionEffect extends ChainEffectDefinition {
  const _TypedDestructionEffect(this.cardInstanceId);

  final String cardInstanceId;

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) => [
        EffectDestructionPending(
          sourceLinkId: link.linkId,
          cardInstanceId: cardInstanceId,
        ),
      ];

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

final class _TypedBanishmentEffect extends ChainEffectDefinition {
  const _TypedBanishmentEffect(this.cardInstanceId);

  final String cardInstanceId;

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) => [
        BanishmentPending(
          sourceLinkId: link.linkId,
          cardInstanceId: cardInstanceId,
          fromGraveyard: true,
        ),
      ];

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

final class _TypedRevealEffect extends ChainEffectDefinition {
  const _TypedRevealEffect(this.cardInstanceId);

  final String cardInstanceId;

  @override
  Iterable<PendingDuelEvent> pendingEvents(DuelState state, ChainLink link) => [
        FaceDownRevealPending(
          sourceLinkId: link.linkId,
          cardInstanceIds: [cardInstanceId],
        ),
      ];

  @override
  DuelState resolve(DuelState state, ChainLink link) => state;
}

_Scenario _attackScenario(String code, DuelEngine engine) {
  final source = _source(code);
  var target = _card('TARGET',
      id: 'target', family: 'babi', position: BattlePosition.defense);
  final playerCharacters = <CardInstance?>[target];
  if (code == 'MAS-011') {
    target = _card('MAS-TARGET',
        id: 'target',
        family: 'masque',
        faceUp: false,
        position: BattlePosition.defense);
    playerCharacters
      ..clear()
      ..addAll([target, _card('MAS-ALT', id: 'alternate', family: 'masque')]);
  } else if (code == 'SAV-012') {
    target = _card('SAV-TARGET', id: 'target', family: 'savane');
    playerCharacters
      ..clear()
      ..addAll([target, _card('SAV-ALT', id: 'alternate', family: 'savane')]);
  } else if (code == 'VIL-011') {
    target = _card('VIL-TARGET',
        id: 'target', family: 'village', position: BattlePosition.defense);
    playerCharacters
      ..clear()
      ..add(target);
  } else if (code == 'MAQ-011') {
    playerCharacters.add(_card('MAQ-ALLY', id: 'maquis', family: 'maquis'));
  }
  final attacker = _card(
    'ATTACKER',
    id: 'attacker',
    owner: DuelParticipant.ai,
    family: 'savane',
  );
  final state = DuelState(
    turnNumber: 2,
    activePlayer: DuelParticipant.ai,
    currentPhase: DuelPhase.battle,
    playerField: _field(
      participant: DuelParticipant.player,
      characters: playerCharacters,
      backrow: [source],
    ),
    aiField: _field(
      participant: DuelParticipant.ai,
      characters: [attacker],
    ),
  );
  final declaration = engine.declareAttack(
    state: state,
    participant: DuelParticipant.ai,
    attackerInstanceId: attacker.instanceId,
    targetInstanceId: target.instanceId,
  );
  expect(declaration.succeeded, isTrue);
  return _Scenario(
    declaration.state,
    ManualActivationContext(attack: declaration.declaration),
  );
}

_Scenario _scenario(String code, DuelEngine engine) {
  if (code.endsWith('011') || code == 'SAV-012') {
    if (code != 'ANC-011' && code != 'LAG-011') {
      return _attackScenario(code, engine);
    }
  }
  final source = _source(code);
  final ownCharacters = <CardInstance?>[];
  final enemyCharacters = <CardInstance?>[];
  final ownBackrow = <CardInstance?>[];
  final ownHand = <CardInstance>[];
  final ownGraveyard = <CardInstance>[];
  var phase = DuelPhase.main1;
  var active = DuelParticipant.ai;
  var chain = ChainState.closed();
  var context = const ManualActivationContext();

  if (source.category == CardCategory.action && code != 'VIL-009') {
    ownHand.add(source);
    chain = _responseChain(_enemyLink());
  } else if (code == 'VIL-009') {
    ownHand.add(source);
    active = DuelParticipant.player;
  } else {
    ownBackrow.add(source);
    chain = ChainState(
      window: ResponseWindowType.effectActivation,
      priorityPlayer: DuelParticipant.player,
    );
  }

  switch (code) {
    case 'ROY-009':
      ownCharacters.addAll([
        _card('ROY-TARGET', id: 'protected', family: 'royaume'),
        _card('TRIBUTE', id: 'tribute', family: 'village'),
      ]);
      chain = _responseChain(
          _enemyLink(target: ChainTarget(cardInstanceId: 'protected')));
    case 'ROY-012':
      ownCharacters
          .add(_card('ROY-TARGET', id: 'protected', family: 'royaume'));
      chain = _responseChain(
          _enemyLink(target: ChainTarget(cardInstanceId: 'protected')));
    case 'ANC-009':
      ownCharacters.add(_card('ANC-ALLY', id: 'ally', family: 'ancêtre'));
      enemyCharacters
          .add(_card('ENEMY', id: 'enemy', owner: DuelParticipant.ai));
    case 'ANC-011':
      ownGraveyard
          .add(_card('ANC-GRAVE', id: 'grave', family: 'ancêtre', rank: 3));
      context = const ManualActivationContext(destroyedCharacterRank: 5);
    case 'ANC-012':
      ownGraveyard.add(_card('ANC-GRAVE', id: 'grave', family: 'ancêtre'));
      chain = _responseChain(
          _enemyLink(target: ChainTarget(cardInstanceId: 'grave')));
    case 'MAS-008':
      ownCharacters.add(_card('MAS-ALLY',
          id: 'ally',
          family: 'masque',
          faceUp: false,
          position: BattlePosition.defense));
    case 'MAS-012':
      ownCharacters.add(_card('MAS-HIDDEN',
          id: 'hidden',
          family: 'masque',
          faceUp: false,
          position: BattlePosition.defense));
      chain = _responseChain(
          _enemyLink(target: ChainTarget(cardInstanceId: 'hidden')));
    case 'DOZ-009':
      enemyCharacters.add(_card('PREY',
          id: 'prey', owner: DuelParticipant.ai, counters: const {'proie': 1}));
    case 'DOZ-012':
      final prey = _card('PREY',
          id: 'prey', owner: DuelParticipant.ai, counters: const {'proie': 1});
      enemyCharacters.add(prey);
      chain = _responseChain(_enemyLink(sourceId: prey.instanceId));
    case 'FOR-012':
      context = const ManualActivationContext(destroyedWasForest: true);
    case 'LAG-008':
      ownCharacters
          .add(_card('LAG-ALLY', id: 'ally', family: 'lagune', rank: 5));
      enemyCharacters
          .add(_card('ENEMY', id: 'enemy', owner: DuelParticipant.ai, rank: 4));
    case 'LAG-011':
      enemyCharacters.add(_card('SUMMONED',
          id: 'summoned', owner: DuelParticipant.ai, rank: 4));
      context =
          const ManualActivationContext(summonedOpponentInstanceId: 'summoned');
    case 'LAG-012':
      ownCharacters.add(_card('LAG-TARGET', id: 'protected', family: 'lagune'));
      chain = _responseChain(
          _enemyLink(target: ChainTarget(cardInstanceId: 'protected')));
    case 'SAV-009':
      phase = DuelPhase.battle;
      ownCharacters.add(_card('SAV-ALLY', id: 'ally', family: 'savane'));
    case 'VIL-009':
      ownCharacters.add(_card('VIL-ALLY', id: 'ally', family: 'village'));
    case 'VIL-012':
      final equipment = _card('EQUIPMENT',
          id: 'equipment',
          category: CardCategory.action,
          subtype: 'equipment',
          family: 'village',
          position: null);
      ownBackrow.add(equipment);
      chain = _responseChain(_enemyLink(
          target: ChainTarget(cardInstanceId: equipment.instanceId)));
    case 'MAQ-009':
      ownCharacters
          .add(_card('MAQ-HIGH', id: 'high', family: 'maquis', rank: 5));
      ownHand.add(_card('MAQ-LOW',
          id: 'low', family: 'maquis', rank: 3, faceUp: false, position: null));
    case 'MAQ-012':
      ownHand.add(_card('DISCARD',
          id: 'discard', family: 'babi', faceUp: false, position: null));
      chain = _responseChain(_enemyLink());
      context =
          const ManualActivationContext(opponentEffectWouldLoseLife: true);
  }

  return _Scenario(
    DuelState(
      turnNumber: 2,
      activePlayer: active,
      currentPhase: phase,
      chain: chain,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: ownHand,
        characters: ownCharacters,
        backrow: ownBackrow,
        graveyard: ownGraveyard,
      ),
      aiField: _field(
        participant: DuelParticipant.ai,
        characters: enemyCharacters,
      ),
    ),
    context,
  );
}

void main() {
  final cases = _keys.keys.toList(growable: false);

  for (final code in cases) {
    test('$code est découvert et activable par le planificateur générique', () {
      final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
      final scenario = _scenario(code, engine);
      final options = ManualActivationPlanner(engine).legalOptions(
        state: scenario.state,
        participant: DuelParticipant.player,
        context: scenario.context,
      );
      final option =
          options.where((item) => item.source.cardCode == code).firstOrNull;
      expect(option, isNotNull,
          reason: 'Aucune activation légale préparée pour $code');
      final activation = engine.activateCard(
        state: scenario.state,
        participant: DuelParticipant.player,
        cardInstanceId: option!.source.instanceId,
        link: option.link,
      );
      expect(activation.succeeded, isTrue, reason: activation.failure?.name);
    });
  }

  test('un effet automatique de retournement n’apparaît jamais dans la fenêtre',
      () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final automatic = _card(
      'MAS-001',
      id: 'automatic-flip',
      family: 'masque',
      faceUp: false,
      position: BattlePosition.defense,
    ).copyWith(effectKey: MasqueEffectKeys.mas001);
    final state = DuelState(
      turnNumber: 2,
      currentPhase: DuelPhase.battle,
      chain: ChainState(
        window: ResponseWindowType.attackDeclaration,
        priorityPlayer: DuelParticipant.player,
      ),
      playerField: _field(
        participant: DuelParticipant.player,
        characters: [automatic],
      ),
      aiField: _field(participant: DuelParticipant.ai),
    );
    final options = ManualActivationPlanner(engine).legalOptions(
      state: state,
      participant: DuelParticipant.player,
    );
    expect(options.where((option) => option.source.cardCode == 'MAS-001'),
        isEmpty);
  });

  test('le moteur expose les menaces typées des effets de production', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final emptyPlayer = _field(participant: DuelParticipant.player);
    final emptyAi = _field(participant: DuelParticipant.ai);

    DuelState withLink(ChainLink link) => DuelState(
          playerField: emptyPlayer,
          aiField: emptyAi,
          chain: _responseChain(link),
        );

    final revealLink = ChainLink(
      linkId: 'reveal',
      effectKey: MasqueEffectKeys.mas009,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      payload: const {
        'reveal_instance_ids': ['hidden-a', 'hidden-b'],
      },
    );
    final reveal = engine
        .pendingEventsForCurrentChain(withLink(revealLink))
        .single as FaceDownRevealPending;
    expect(reveal.cardInstanceIds, {'hidden-a', 'hidden-b'});

    final destructionLink = ChainLink(
      linkId: 'destroy',
      effectKey: LaguneEffectKeys.lag007,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      target: ChainTarget(cardInstanceId: 'threatened-card'),
    );
    final destruction = engine
        .pendingEventsForCurrentChain(withLink(destructionLink))
        .single as EffectDestructionPending;
    expect(destruction.cardInstanceId, 'threatened-card');

    final banishLink = ChainLink(
      linkId: 'banish',
      effectKey: DozoEffectKeys.doz015,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
      target: ChainTarget(cardInstanceId: 'banished-card'),
    );
    final banishment = engine
        .pendingEventsForCurrentChain(withLink(banishLink))
        .single as BanishmentPending;
    expect(banishment.cardInstanceId, 'banished-card');
    expect(banishment.fromGraveyard, isFalse);
  });

  test('une perte de PV typée propose automatiquement MAQ-012', () {
    final effects = {
      ...V2EffectRegistry.create(),
      'typed-life-loss': const _TypedLifeLossEffect(),
    };
    final engine = DuelEngine(chainEffects: effects);
    final trap = _source('MAQ-012');
    final discard = _card(
      'DISCARD',
      id: 'discard-for-maq',
      family: 'babi',
      faceUp: false,
      position: null,
    );
    final threat = ChainLink(
      linkId: 'life-loss-link',
      effectKey: 'typed-life-loss',
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: [discard],
        backrow: [trap],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseChain(threat),
    );

    final option = ManualActivationPlanner(engine)
        .legalOptions(
          state: state,
          participant: DuelParticipant.player,
        )
        .singleWhere((candidate) => candidate.source.cardCode == 'MAQ-012');

    expect(option.link.payload['target_link_id'], threat.linkId);
    expect(option.link.payload['discard_instance_id'], discard.instanceId);
  });

  test('un bannissement typé propose ANC-012 sans payload conventionnel', () {
    const effectKey = 'typed-banishment';
    final effects = {
      ...V2EffectRegistry.create(),
      effectKey: const _TypedBanishmentEffect('ancestor-in-grave'),
    };
    final engine = DuelEngine(chainEffects: effects);
    final threat = ChainLink(
      linkId: 'banishment-link',
      effectKey: effectKey,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      playerField: _field(
        participant: DuelParticipant.player,
        backrow: [_source('ANC-012')],
        graveyard: [
          _card('ANC-GRAVE', id: 'ancestor-in-grave', family: 'ancêtre'),
        ],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseChain(threat),
    );

    final option = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.player)
        .singleWhere((candidate) => candidate.source.cardCode == 'ANC-012');

    expect(option.link.payload['target_link_id'], threat.linkId);
    expect(option.link.payload['threatened_graveyard_instance_id'],
        'ancestor-in-grave');
  });

  test('une révélation typée propose MAS-012 sans payload conventionnel', () {
    const effectKey = 'typed-reveal';
    final effects = {
      ...V2EffectRegistry.create(),
      effectKey: const _TypedRevealEffect('hidden-mask'),
    };
    final engine = DuelEngine(chainEffects: effects);
    final threat = ChainLink(
      linkId: 'reveal-link',
      effectKey: effectKey,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      playerField: _field(
        participant: DuelParticipant.player,
        characters: [
          _card(
            'MAS-HIDDEN',
            id: 'hidden-mask',
            family: 'masque',
            faceUp: false,
            position: BattlePosition.defense,
          ),
        ],
        backrow: [_source('MAS-012')],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseChain(threat),
    );

    final option = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.player)
        .singleWhere((candidate) => candidate.source.cardCode == 'MAS-012');

    expect(option.link.payload['target_link_id'], threat.linkId);
    expect(option.link.payload['threatened_face_down_instance_ids'],
        ['hidden-mask']);
  });

  test('une destruction typée propose LAG-012 sans cible conventionnelle', () {
    const effectKey = 'typed-destruction';
    final effects = {
      ...V2EffectRegistry.create(),
      effectKey: const _TypedDestructionEffect('protected-lagune'),
    };
    final engine = DuelEngine(chainEffects: effects);
    final threat = ChainLink(
      linkId: 'destruction-link',
      effectKey: effectKey,
      activatingPlayer: DuelParticipant.ai,
      speed: ChainSpeed.speed1,
    );
    final state = DuelState(
      turnNumber: 2,
      playerField: _field(
        participant: DuelParticipant.player,
        characters: [
          _card('LAG-TARGET', id: 'protected-lagune', family: 'lagune'),
        ],
        backrow: [_source('LAG-012')],
      ),
      aiField: _field(participant: DuelParticipant.ai),
      chain: _responseChain(threat),
    );

    final option = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.player)
        .singleWhere((candidate) => candidate.source.cardCode == 'LAG-012');

    expect(option.link.target?.cardInstanceId, 'protected-lagune');
    expect(option.link.payload['target_link_id'], threat.linkId);
  });

  test('une cible posée adverse est préparée sans logique UI spécifique', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final action = _card(
      'BAB-009',
      id: 'network',
      category: CardCategory.action,
      subtype: 'normal',
      position: null,
      faceUp: false,
      effectKey: BabiEffectKeys.bab009,
    );
    final hidden = _card(
      'HIDDEN',
      id: 'hidden',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      subtype: 'normal',
      position: null,
      faceUp: false,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: [action],
      ),
      aiField: _field(
        participant: DuelParticipant.ai,
        backrow: [hidden],
      ),
    );
    final option = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.player)
        .single;
    expect(option.link.target?.cardInstanceId, hidden.instanceId);
  });

  test('un coût de bannissement depuis le Cimetière est préparé et payé', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final action = _card(
      'ANC-010',
      id: 'ancestral-call',
      category: CardCategory.action,
      subtype: 'normal',
      position: null,
      faceUp: false,
      effectKey: AncetreEffectKeys.anc010,
    );
    final rankSix = _card(
      'ANC-A',
      id: 'rank-six',
      family: 'ancêtre',
      rank: 6,
    );
    final rankFour = _card(
      'ANC-B',
      id: 'rank-four',
      family: 'ancêtre',
      rank: 4,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.main1,
      playerField: _field(
        participant: DuelParticipant.player,
        hand: [action],
        graveyard: [rankSix, rankFour],
      ),
      aiField: _field(participant: DuelParticipant.ai),
    );
    final option = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.player)
        .single;
    expect(option.link.payload['banish_instance_ids'],
        containsAll([rankSix.instanceId, rankFour.instanceId]));
    final result = engine.activateCard(
      state: state,
      participant: DuelParticipant.player,
      cardInstanceId: action.instanceId,
      link: option.link,
    );
    expect(result.succeeded, isTrue);
    expect(result.state.playerField.banished, hasLength(2));
  });

  test('les IA débutante, avancée et experte utilisent une Action rapide Forêt',
      () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final quick = _card(
      'FOR-008',
      id: 'ai-quick',
      owner: DuelParticipant.ai,
      category: CardCategory.action,
      subtype: 'quick',
      position: null,
      faceUp: false,
      effectKey: ForetEffectKeys.for008,
    );
    final state = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.ai,
      currentPhase: DuelPhase.main1,
      chain: ChainState(
        window: ResponseWindowType.effectActivation,
        priorityPlayer: DuelParticipant.ai,
      ),
      playerField: _field(participant: DuelParticipant.player),
      aiField: _field(participant: DuelParticipant.ai, hand: [quick]),
    );
    final links = ManualActivationPlanner(engine)
        .legalOptions(state: state, participant: DuelParticipant.ai)
        .map((option) => option.link)
        .toList();
    expect(links, hasLength(1));
    for (final difficulty in [
      AiDifficulty.beginner,
      AiDifficulty.advanced,
      AiDifficulty.expert,
    ]) {
      final ai = createDuelAi(difficulty: difficulty, engine: engine);
      expect(
        ai
            .chooseChainActivation(
              state: state,
              availableActivations: links,
            )
            ?.sourceCardCode,
        'FOR-008',
        reason: difficulty.name,
      );
    }
  });

  test('l’IA intermédiaire active un Piège Forêt contre une attaque forte', () {
    final engine = DuelEngine(chainEffects: V2EffectRegistry.create());
    final trap = _card(
      'FOR-011',
      id: 'ai-trap',
      owner: DuelParticipant.ai,
      category: CardCategory.trap,
      subtype: 'normal',
      position: null,
      faceUp: false,
      effectKey: ForetEffectKeys.for011,
      runtimeData: const {CardRuntimeKeys.setOnTurn: 1},
    );
    final attacker = _card(
      'ATTACKER',
      id: 'player-attacker',
      atk: 3000,
    );
    final defender = _card(
      'DEFENDER',
      id: 'ai-defender',
      owner: DuelParticipant.ai,
      position: BattlePosition.defense,
    );
    final initial = DuelState(
      turnNumber: 2,
      activePlayer: DuelParticipant.player,
      currentPhase: DuelPhase.battle,
      playerField: _field(
        participant: DuelParticipant.player,
        characters: [attacker],
      ),
      aiField: _field(
        participant: DuelParticipant.ai,
        characters: [defender],
        backrow: [trap],
      ),
    );
    final declaration = engine.declareAttack(
      state: initial,
      participant: DuelParticipant.player,
      attackerInstanceId: attacker.instanceId,
      targetInstanceId: defender.instanceId,
    );
    final links = ManualActivationPlanner(engine)
        .legalOptions(
          state: declaration.state,
          participant: DuelParticipant.ai,
          context: ManualActivationContext(attack: declaration.declaration),
        )
        .map((option) => option.link)
        .toList();
    final ai = createDuelAi(
      difficulty: AiDifficulty.intermediate,
      engine: engine,
    );
    expect(
      ai
          .chooseChainActivation(
            state: declaration.state,
            availableActivations: links,
          )
          ?.sourceCardCode,
      'FOR-011',
    );
  });
}
