class SupabaseConfig {
  static const _defaultUrl = 'https://uwxeqqajqkhddzgkmflk.supabase.co';
  static const _defaultAnonKey =
      'sb_publishable_AZ5tv9szTn1QT9AvdxSPJQ_VfOU1C2g';

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
