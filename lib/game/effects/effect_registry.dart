import '../duel_engine.dart';
import 'ancetre_effects.dart';
import 'babi_effects.dart';
import 'dozo_effects.dart';
import 'foret_effects.dart';
import 'lagune_effects.dart';
import 'maquis_effects.dart';
import 'masque_effects.dart';
import 'royaume_effects.dart';
import 'savane_effects.dart';
import 'village_effects.dart';

/// Registre de production unique des effets du set de lancement V2.
///
/// Les tests de famille peuvent continuer à injecter un registre réduit, mais
/// un duel réel doit connaître les dix familles afin que les déclenchements,
/// retournements et invocations Mythiques utilisent tous la même Chaîne.
abstract final class V2EffectRegistry {
  static Map<String, ChainEffectDefinition> create() => {
        ...BabiEffectRegistry.create(),
        ...RoyaumeEffectRegistry.create(),
        ...AncetreEffectRegistry.create(),
        ...MasqueEffectRegistry.create(),
        ...DozoEffectRegistry.create(),
        ...ForetEffectRegistry.create(),
        ...LaguneEffectRegistry.create(),
        ...SavaneEffectRegistry.create(),
        ...VillageEffectRegistry.create(),
        ...MaquisEffectRegistry.create(),
      };
}
