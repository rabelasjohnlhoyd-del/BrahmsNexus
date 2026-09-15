/// Configuration for Google AI Studio (Gemini API).
class GeminiConfig {
  const GeminiConfig._();

  // ===========================================================================
  // 👉 I-PASTE DITO ANG IYONG API KEY MULA SA GOOGLE AI STUDIO:
  //    Palitan ang 'PASTE_YOUR_API_KEY_HERE' ng iyong key (hal. 'AQ...' o 'AIza...')
  // ===========================================================================
  static const String key = 'PASTE_YOUR_API_KEY_HERE';

  /// The active API key — just reads from the single [key] above.
  static String get apiKey => key.trim();

  /// Checks if the API key has been configured (not the placeholder default)
  static bool get isConfigured =>
      key.isNotEmpty && key != 'PASTE_YOUR_API_KEY_HERE';
}
