import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/game/battle_state.dart';
import 'package:mysticartes/game/card.dart';
import 'package:mysticartes/game/duel_engine.dart';
import 'package:mysticartes/game/duel_types.dart';
import 'package:mysticartes/game/effects/effect_registry.dart';
import 'package:mysticartes/game/player.dart';

final class _DamageEffect extends ChainEffectDefinition {
  const _DamageEffect();

  @override
  DuelState resolve(DuelState state, ChainLink link) => state.copyWith(
        aiLifePoints: state.aiLifePoints - 100,
      );
}

CardInstance _card({
  required String id,
  required CardCategory category,
  String? subtype,
}) =>
    CardInstance(
      instanceId: id,
      cardId: 'catalog-$id',
      cardCode: id.toUpperCase(),
      cardRevision: 1,
      category: category,
      rank: null,
      subtype: subtype,
      effectKey: 'damage',
      owner: DuelParticipant.player,
      controller: DuelParticipant.player,
      faceUp: false,
      position: null,
    );

DuelState _stateWithHand(CardInstance card) => DuelState(
      currentPhase: DuelPhase.main1,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
      ).copyWith(hand: [card]),
      aiField: PlayerFieldState.empty(participant: DuelParticipant.ai),
    );

ChainLink _link(CardInstance card) => ChainLink(
      linkId: 'link-${card.instanceId}',
      effectKey: 'damage',
      activatingPlayer: DuelParticipant.player,
      speed: ChainSpeed.speed1,
      sourceCardInstanceId: card.instanceId,
      sourceCardCode: card.cardCode,
    );

DuelState _resolve(DuelEngine engine, DuelState state) {
  var pass = engine.passPriority(
    state: state,
    participant: DuelParticipant.ai,
  );
  expect(pass.succeeded, isTrue);
  pass = engine.passPriority(
    state: pass.state,
    participant: DuelParticipant.player,
  );
  expect(pass.resolutionTriggered, isTrue);
  return pass.state;
}

void main() {
  test('le registre de production rassemble les dix familles', () {
    final effects = V2EffectRegistry.create();
    expect(effects, hasLength(140));
    expect(effects, contains('bab_008_trajet_express'));
    expect(effects, contains('maq_015_grand_maquisard_cosmique'));
  });

  test('une Action activée depuis la main rejoint le Cimetière', () {
    final action = _card(id: 'action', category: CardCategory.action);
    final engine = DuelEngine(chainEffects: const {'damage': _DamageEffect()});
    final activation = engine.activateCard(
      state: _stateWithHand(action),
      participant: DuelParticipant.player,
      cardInstanceId: action.instanceId,
      link: _link(action),
    );

    expect(activation.succeeded, isTrue);
    final resolved = _resolve(engine, activation.state);
    expect(resolved.aiLifePoints, 7900);
    expect(resolved.playerField.hand, isEmpty);
    expect(resolved.playerField.actionTrapZones, everyElement(isNull));
    expect(resolved.playerField.graveyard.single.instanceId, 'action');
  });

  test('un Terrain activé reste dans sa Zone Terrain', () {
    final terrain = _card(id: 'terrain', category: CardCategory.terrain);
    final engine = DuelEngine(chainEffects: const {'damage': _DamageEffect()});
    final activation = engine.activateCard(
      state: _stateWithHand(terrain),
      participant: DuelParticipant.player,
      cardInstanceId: terrain.instanceId,
      link: _link(terrain),
    );

    final resolved = _resolve(engine, activation.state);
    expect(resolved.playerField.terrainZone?.instanceId, 'terrain');
    expect(resolved.playerField.terrainZone?.faceUp, isTrue);
    expect(resolved.playerField.graveyard, isEmpty);
  });

  test('un Piège posé ce tour ne peut pas être activé immédiatement', () {
    final trap = _card(
      id: 'trap',
      category: CardCategory.trap,
      subtype: 'normal',
    ).copyWith(
      zoneIndex: 0,
      runtimeData: {CardRuntimeKeys.setOnTurn: 1},
    );
    final state = DuelState(
      currentPhase: DuelPhase.main1,
      playerField: PlayerFieldState.empty(
        participant: DuelParticipant.player,
      ).copyWith(actionTrapZones: [trap, null, null, null, null]),
      aiField: PlayerFieldState.empty(participant: DuelParticipant.ai),
    );
    final engine = DuelEngine(chainEffects: const {'damage': _DamageEffect()});
    final activation = engine.activateCard(
      state: state,
      participant: DuelParticipant.player,
      cardInstanceId: trap.instanceId,
      link: ChainLink(
        linkId: 'trap-link',
        effectKey: 'damage',
        activatingPlayer: DuelParticipant.player,
        speed: ChainSpeed.speed2,
        sourceCardInstanceId: trap.instanceId,
      ),
    );

    expect(activation.succeeded, isFalse);
    expect(
      activation.failure,
      DuelActionFailure.chainActivationConditionNotMet,
    );
    expect(activation.state.playerField.actionTrapZones.first?.faceUp, isFalse);
  });
}
