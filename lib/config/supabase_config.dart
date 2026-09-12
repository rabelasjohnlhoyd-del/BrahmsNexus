/// Configuration for the Supabase backend.
///
/// Paste your Project URL and anon public key from your Supabase Dashboard:
/// (Settings -> API -> Project URL & Project API Keys / anon public)
class SupabaseConfig {
  const SupabaseConfig._();

  /// Supabase project URL loaded via --dart-define=SUPABASE_URL=... or fallback.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-ref.supabase.co/',
  );

  /// Supabase anon public key loaded via --dart-define=SUPABASE_ANON_KEY=... or fallback.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  /// Returns true if the configuration has been updated with real project credentials.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
          !supabaseUrl.contains('your-project-ref') &&
          supabaseAnonKey.isNotEmpty &&
          !supabaseAnonKey.contains('your-anon-key');
}