import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Persists whether each role's guided tour has been seen using SharedPreferences.
///
/// Keys are scoped **per user account** (using the logged-in user's UID) so that
/// each staff member gets their own tutorial state even on a shared device.
///
/// Key format: `tutorial_<tourKey>_seen_<userId>`
///
/// This means:
/// - jobelle_fuentes logs in → sees tour → marked seen for her UID only
/// - leany_malla logs in on the same device → her UID has no flag → sees tour ✅
class TutorialService {
  static String _prefKey(String tourKey) {
    final uid = AuthService.currentUserId;
    return 'tutorial_${tourKey}_seen_$uid';
  }

  static Future<bool> hasSeenTutorial(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey(tourKey)) ?? false;
  }

  static Future<void> markTutorialSeen(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(tourKey), true);
  }

  static Future<void> resetTutorial(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey(tourKey));
  }
}
