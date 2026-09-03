import 'duel_types.dart';

const Object _notProvided = Object();

abstract final class CardRuntimeKeys {
  static const cannotAttackTurn = 'cannot_attack_turn';
  static const cannotBeSacrificedTurn = 'cannot_be_sacrificed_turn';
  static const cannotBeDestroyedInBattleTurn =
      'cannot_be_destroyed_in_battle_turn';
  static const directAttackAllowedTurn = 'direct_attack_allowed_turn';
  static const directAttackForbiddenTurn = 'direct_attack_forbidden_turn';
  static const directAttackDamageDivisor = 'direct_attack_damage_divisor';
  static const effectsNegatedUntilTurn = 'effects_negated_until_turn';
  static const equippedToInstanceId = 'equipped_to_instance_id';
  static const flippedFaceUpTurn = 'flipped_face_up_turn';
  static const positionLockedTurn = 'position_locked_turn';
  static const setOnTurn = 'set_on_turn';
  static const sameTurnTrapActivationAllowed =
      'same_turn_trap_activation_allowed';
  static const combatOnlyAtkDelta = 'combat_only_atk_delta';
  static const combatOnlyDefDelta = 'combat_only_def_delta';
  static const combatDamageDivisor = 'combat_damage_divisor';
  static const combatDamageDivisorTurn = 'combat_damage_divisor_turn';
  static const savaneSpearEquipped = 'savane_spear_equipped';
  static const pendingOneShotChainLink = 'pending_one_shot_chain_link';
}

/// Bonus ou malus de statistiques attaché à une instance pendant le duel.
///
/// Sa durée n'est volontairement pas interprétée ici : cette étape ne décrit
/// que les données que le futur moteur de résolution pourra consommer.
final class RuntimeStatModifier {
  RuntimeStatModifier({
    required this.modifierId,
    this.atkDelta = 0,
    this.defDelta = 0,
    this.sourceCardInstanceId,
    this.expiresAtTurn,
    this.expiresAfterPhase,
    Map<String, Object?> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  final String modifierId;
  final int atkDelta;
  final int defDelta;
  final String? sourceCardInstanceId;
  final int? expiresAtTurn;
  final DuelPhase? expiresAfterPhase;
  final Map<String, Object?> metadata;

  RuntimeStatModifier copyWith({
    String? modifierId,
    int? atkDelta,
    int? defDelta,
    Object? sourceCardInstanceId = _notProvided,
    Object? expiresAtTurn = _notProvided,
    Object? expiresAfterPhase = _notProvided,
    Map<String, Object?>? metadata,
  }) {
    return RuntimeStatModifier(
      modifierId: modifierId ?? this.modifierId,
      atkDelta: atkDelta ?? this.atkDelta,
      defDelta: defDelta ?? this.defDelta,
      sourceCardInstanceId: identical(sourceCardInstanceId, _notProvided)
          ? this.sourceCardInstanceId
          : sourceCardInstanceId as String?,
      expiresAtTurn: identical(expiresAtTurn, _notProvided)
          ? this.expiresAtTurn
          : expiresAtTurn as int?,
      expiresAfterPhase: identical(expiresAfterPhase, _notProvided)
          ? this.expiresAfterPhase
          : expiresAfterPhase as DuelPhase?,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Données communes à toute carte pouvant occuper une zone de Personnage.
///
/// Les cartes du catalogue et les jetons partagent cet état de terrain, mais
/// seuls les [CardInstance] peuvent être placés dans les collections hors du
/// terrain de [PlayerFieldState].
sealed class FieldCardInstance {
  FieldCardInstance({
    required this.instanceId,
    required this.owner,
    required this.controller,
    required this.faceUp,
    required this.position,
    this.atk,
    this.def,
    this.zoneIndex,
    this.summonedTurn,
    this.attackedThisTurn = false,
    this.positionChangedThisTurn = false,
    Map<String, int> counters = const {},
    List<String> attachedCardInstanceIds = const [],
    List<RuntimeStatModifier> runtimeModifiers = const [],
  })  : counters = Map.unmodifiable(counters),
        attachedCardInstanceIds = List.unmodifiable(attachedCardInstanceIds),
        runtimeModifiers = List.unmodifiable(runtimeModifiers);

  final String instanceId;
  final DuelParticipant owner;
  final DuelParticipant controller;
  final bool faceUp;
  final BattlePosition? position;
  final int? atk;
  final int? def;
  final int? zoneIndex;
  final int? summonedTurn;
  final bool attackedThisTurn;
  final bool positionChangedThisTurn;

  /// Marqueurs génériques, indexés par une clé métier libre.
  ///
  /// Exemples actuels : `proie`, `graine`, `mémoire`, `nom`, `outil`,
  /// `portion` et `serment`. Aucun ajout de champ n'est nécessaire pour de
  /// futurs types de marqueurs.
  final Map<String, int> counters;

  final List<String> attachedCardInstanceIds;
  final List<RuntimeStatModifier> runtimeModifiers;

  int? get effectiveAtk {
    final baseValue = atk;
    if (baseValue == null) return null;
    return runtimeModifiers.fold<int>(
      baseValue,
      (value, modifier) => value + modifier.atkDelta,
    );
  }

  int? get effectiveDef {
    final baseValue = def;
    if (baseValue == null) return null;
    return runtimeModifiers.fold<int>(
      baseValue,
      (value, modifier) => value + modifier.defDelta,
    );
  }
}

/// Instance concrète d'une définition du catalogue V2.
final class CardInstance extends FieldCardInstance {
  CardInstance({
    required super.instanceId,
    required this.cardId,
    required this.cardCode,
    required this.cardRevision,
    required this.category,
    required this.rank,
    this.subtype,
    this.attribute,
    this.primaryFamily,
    List<String> secondaryFamilies = const [],
    Map<String, Object?> mythicSummonCondition = const {},
    this.effectKey,
    Map<String, Object?> effectData = const {},
    required super.owner,
    required super.controller,
    required super.faceUp,
    required super.position,
    super.atk,
    super.def,
    super.zoneIndex,
    super.summonedTurn,
    super.attackedThisTurn,
    super.positionChangedThisTurn,
    super.counters,
    super.attachedCardInstanceIds,
    super.runtimeModifiers,
    Map<String, int> effectUsageTurns = const {},
    Map<String, Object?> runtimeData = const {},
  })  : secondaryFamilies = List.unmodifiable(secondaryFamilies),
        mythicSummonCondition = Map.unmodifiable(mythicSummonCondition),
        effectData = Map.unmodifiable(effectData),
        effectUsageTurns = Map.unmodifiable(effectUsageTurns),
        runtimeData = Map.unmodifiable(runtimeData);

  final String cardId;
  final String cardCode;
  final int cardRevision;
  final CardCategory category;
  final int? rank;
  final String? subtype;
  final String? attribute;
  final String? primaryFamily;
  final List<String> secondaryFamilies;
  final Map<String, Object?> mythicSummonCondition;
  final String? effectKey;
  final Map<String, Object?> effectData;
  final Map<String, int> effectUsageTurns;
  final Map<String, Object?> runtimeData;

  bool hasFamily(String family) {
    return primaryFamily == family || secondaryFamilies.contains(family);
  }

  CardInstance copyWith({
    String? instanceId,
    String? cardId,
    String? cardCode,
    int? cardRevision,
    CardCategory? category,
    Object? rank = _notProvided,
    Object? subtype = _notProvided,
    Object? attribute = _notProvided,
    Object? primaryFamily = _notProvided,
    List<String>? secondaryFamilies,
    Map<String, Object?>? mythicSummonCondition,
    Object? effectKey = _notProvided,
    Map<String, Object?>? effectData,
    DuelParticipant? owner,
    DuelParticipant? controller,
    bool? faceUp,
    Object? position = _notProvided,
    Object? atk = _notProvided,
    Object? def = _notProvided,
    Object? zoneIndex = _notProvided,
    Object? summonedTurn = _notProvided,
    bool? attackedThisTurn,
    bool? positionChangedThisTurn,
    Map<String, int>? counters,
    List<String>? attachedCardInstanceIds,
    List<RuntimeStatModifier>? runtimeModifiers,
    Map<String, int>? effectUsageTurns,
    Map<String, Object?>? runtimeData,
  }) {
    return CardInstance(
      instanceId: instanceId ?? this.instanceId,
      cardId: cardId ?? this.cardId,
      cardCode: cardCode ?? this.cardCode,
      cardRevision: cardRevision ?? this.cardRevision,
      category: category ?? this.category,
      rank: identical(rank, _notProvided) ? this.rank : rank as int?,
      subtype:
          identical(subtype, _notProvided) ? this.subtype : subtype as String?,
      attribute: identical(attribute, _notProvided)
          ? this.attribute
          : attribute as String?,
      primaryFamily: identical(primaryFamily, _notProvided)
          ? this.primaryFamily
          : primaryFamily as String?,
      secondaryFamilies: secondaryFamilies ?? this.secondaryFamilies,
      mythicSummonCondition:
          mythicSummonCondition ?? this.mythicSummonCondition,
      effectKey: identical(effectKey, _notProvided)
          ? this.effectKey
          : effectKey as String?,
      effectData: effectData ?? this.effectData,
      owner: owner ?? this.owner,
      controller: controller ?? this.controller,
      faceUp: faceUp ?? this.faceUp,
      position: identical(position, _notProvided)
          ? this.position
          : position as BattlePosition?,
      atk: identical(atk, _notProvided) ? this.atk : atk as int?,
      def: identical(def, _notProvided) ? this.def : def as int?,
      zoneIndex: identical(zoneIndex, _notProvided)
          ? this.zoneIndex
          : zoneIndex as int?,
      summonedTurn: identical(summonedTurn, _notProvided)
          ? this.summonedTurn
          : summonedTurn as int?,
      attackedThisTurn: attackedThisTurn ?? this.attackedThisTurn,
      positionChangedThisTurn:
          positionChangedThisTurn ?? this.positionChangedThisTurn,
      counters: counters ?? this.counters,
      attachedCardInstanceIds:
          attachedCardInstanceIds ?? this.attachedCardInstanceIds,
      runtimeModifiers: runtimeModifiers ?? this.runtimeModifiers,
      effectUsageTurns: effectUsageTurns ?? this.effectUsageTurns,
      runtimeData: runtimeData ?? this.runtimeData,
    );
  }
}

/// Instance d'un jeton créé pendant un duel.
///
/// Elle ne possède volontairement ni `cardId`, ni `cardCode`, ni révision de
/// catalogue. [PlayerFieldState] n'accepte ce type que dans les zones de
/// Personnage : un jeton ne peut donc pas entrer dans le deck, la main, le
/// Cimetière, le bannissement ou la Réserve des Mythiques.
final class TokenInstance extends FieldCardInstance {
  TokenInstance({
    required super.instanceId,
    required this.tokenKey,
    required super.owner,
    required super.controller,
    super.faceUp = true,
    required BattlePosition super.position,
    super.atk,
    super.def,
    super.zoneIndex,
    super.summonedTurn,
    super.attackedThisTurn,
    super.positionChangedThisTurn,
    super.counters,
    super.attachedCardInstanceIds,
    super.runtimeModifiers,
    Map<String, Object?> runtimeData = const {},
  }) : runtimeData = Map.unmodifiable(runtimeData);

  final String tokenKey;
  final Map<String, Object?> runtimeData;

  TokenInstance copyWith({
    String? instanceId,
    String? tokenKey,
    DuelParticipant? owner,
    DuelParticipant? controller,
    bool? faceUp,
    BattlePosition? position,
    Object? atk = _notProvided,
    Object? def = _notProvided,
    Object? zoneIndex = _notProvided,
    Object? summonedTurn = _notProvided,
    bool? attackedThisTurn,
    bool? positionChangedThisTurn,
    Map<String, int>? counters,
    List<String>? attachedCardInstanceIds,
    List<RuntimeStatModifier>? runtimeModifiers,
    Map<String, Object?>? runtimeData,
  }) {
    return TokenInstance(
      instanceId: instanceId ?? this.instanceId,
      tokenKey: tokenKey ?? this.tokenKey,
      owner: owner ?? this.owner,
      controller: controller ?? this.controller,
      faceUp: faceUp ?? this.faceUp,
      position: position ?? this.position!,
      atk: identical(atk, _notProvided) ? this.atk : atk as int?,
      def: identical(def, _notProvided) ? this.def : def as int?,
      zoneIndex: identical(zoneIndex, _notProvided)
          ? this.zoneIndex
          : zoneIndex as int?,
      summonedTurn: identical(summonedTurn, _notProvided)
          ? this.summonedTurn
          : summonedTurn as int?,
      attackedThisTurn: attackedThisTurn ?? this.attackedThisTurn,
      positionChangedThisTurn:
          positionChangedThisTurn ?? this.positionChangedThisTurn,
      counters: counters ?? this.counters,
      attachedCardInstanceIds:
          attachedCardInstanceIds ?? this.attachedCardInstanceIds,
      runtimeModifiers: runtimeModifiers ?? this.runtimeModifiers,
      runtimeData: runtimeData ?? this.runtimeData,
    );
  }
}
