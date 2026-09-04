import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère le choix « Se souvenir de moi » indépendamment du stockage interne
/// de Supabase. Une session non mémorisée reste utilisable jusqu'à la fermeture
/// de l'application, puis elle est supprimée au lancement suivant.
abstract final class AuthSessionPreferences {
  static const rememberSessionKey = 'auth.remember_session';

  static Future<bool> rememberSession() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(rememberSessionKey) ?? true;
  }

  static Future<void> setRememberSession(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(rememberSessionKey, value);
  }

  static Future<void> applyAtStartup(SupabaseClient client) async {
    if (await rememberSession()) return;
    if (client.auth.currentSession != null) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
  }
}
