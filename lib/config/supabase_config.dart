/// Configuration for the Supabase backend.
///
/// Paste your Project URL and anon public key from your Supabase Dashboard:
/// (Settings -> API -> Project URL & Project API Keys / anon public)
class SupabaseConfig {
  const SupabaseConfig._();

  /// Supabase project URL loaded via --dart-define=SUPABASE_URL=... or fallback.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kumasxtsfkjjvlkptsyz.supabase.co',
  );

  /// Cleans the Supabase URL by removing any trailing `/rest/v1/` or slashes.
  static String get cleanSupabaseUrl {
    var url = supabaseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/rest/v1')) {
      url = url.substring(0, url.length - 8);
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Supabase anon public key loaded via --dart-define=SUPABASE_ANON_KEY=... or fallback.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Q20Rci63zBGFfU8BhB-Vnw_Fa1kWWYT',
  );

  /// Returns true if the configuration has been updated with real project credentials.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
          !supabaseUrl.contains('your-project-ref') &&
          supabaseAnonKey.isNotEmpty &&
          !supabaseAnonKey.contains('your-anon-key');
}