/// Configuration for Google AI Studio (Gemini API).
class GeminiConfig {
  const GeminiConfig._();

  /// 👉 DITO MO LANG I-PASTE ANG IYONG API KEY:
  static const String apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Checks if the API key has been configured (not the placeholder default)
  static bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      apiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
      !apiKey.startsWith('YOUR_GEMINI_API_KEY_HERE');
}
