/// Configuration for Google AI Studio (Gemini API).
class GeminiConfig {
  const GeminiConfig._();

  // ===========================================================================
  // 👉 PRIMARY API KEY:
  //    I-paste dito ang iyong pangunahing API key mula sa Google AI Studio.
  //    (Palitan ang 'PASTE_YOUR_API_KEY_HERE' ng iyong key hal. 'AIzaSy...')
  //    PAALALA: Kung ang key mo ay nagsisimula sa 'AQ.' o 'ya29.', ito ay
  //    Google OAuth Bearer Token. Awtomatiko itong gagamitin bilang Bearer auth.
  // ===========================================================================
  static const String key = '';

  // ===========================================================================
  // 👉 MULTIPLE API KEYS SUPPORT (ROTATION & FAILOVER):
  //    Maaari kang maglagay ng maramihang API keys dito (mula sa magkakaibang Google
  //    accounts o projects). Kapag nag-quota limit (429) o nag-fail ang isang key,
  //    awtomatikong mag-switch ang system sa susunod na key nang walang error!
  // ===========================================================================
  static const List<String> apiKeys = [
    key,
    // 'AIzaSySecondBackupKeyHere...',
    // 'AIzaSyThirdBackupKeyHere...',
  ];

  // ===========================================================================
  // 👉 MODEL ROLLBACK HIERARCHY (GEMINI 3.x SERIES):
  //    Kapag nag-error o busy ang unang model, sunod-sunod na mag-fallback dito.
  //    Ang AQ. Bearer token ay gumagamit ng Gemini 3.x series (hindi 1.5/2.0).
  // ===========================================================================
  static const List<String> fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-3.1-pro',
  ];

  /// List of Gemini 3.x models to try in descending preference.
  static List<String> get models => fallbackModels;

  /// Returns all configured and valid API keys (excludes placeholder & empty strings).
  static List<String> get validKeys {
    final valid = <String>[];
    for (final k in apiKeys) {
      final trimmed = k.trim();
      if (_isValidKey(trimmed) && !valid.contains(trimmed)) {
        valid.add(trimmed);
      }
    }
    // Also include [key] if it was modified directly but not yet added to [apiKeys]
    final direct = key.trim();
    if (_isValidKey(direct) && !valid.contains(direct)) {
      valid.insert(0, direct);
    }
    return valid;
  }

  static bool _isValidKey(String k) {
    final trimmed = k.trim();
    return trimmed.isNotEmpty && trimmed != 'PASTE_YOUR_API_KEY_HERE';
  }

  /// The active primary API key.
  static String get apiKey => validKeys.isNotEmpty ? validKeys.first : key.trim();

  /// True if at least one valid API key is present.
  static bool get isConfigured => validKeys.isNotEmpty;
}
