class SupabaseConfig {
  static const _defaultUrl = '';
  static const _defaultAnonKey =
      '';

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  static void validate() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Set defaults in SupabaseConfig or pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
