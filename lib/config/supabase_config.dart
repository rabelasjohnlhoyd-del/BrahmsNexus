/// Configuration for the Supabase backend.
///
/// Paste your Project URL and anon public key from your Supabase Dashboard:
/// (Settings -> API -> Project URL & Project API Keys / anon public)
class SupabaseConfig {
  const SupabaseConfig._();

  // TODO: Replace with your actual Supabase project URL
  static const String supabaseUrl = 'https://your-project-ref.supabase.co';

  // TODO: Replace with your actual Supabase anon public key
  static const String supabaseAnonKey = 'your-anon-key-here';

  /// Returns true if the configuration has been updated with real project credentials.
  static bool get isConfigured =>
      !supabaseUrl.contains('your-project-ref') &&
      !supabaseAnonKey.contains('your-anon-key');
}
