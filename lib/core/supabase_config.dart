class SupabaseConfig {
  static const _urlFromEnv = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const _anonKeyFromEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const _fallbackUrl = 'https://uwxeqqajqkhddzgkmflk.supabase.co';
  static const _fallbackAnonKey =
      'sb_publishable_AZ5tv9szTn1QT9AvdxSPJQ_VfOU1C2g';

  static String get url => _urlFromEnv.isNotEmpty ? _urlFromEnv : _fallbackUrl;
  static String get anonKey =>
      _anonKeyFromEnv.isNotEmpty ? _anonKeyFromEnv : _fallbackAnonKey;

  static void validate() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Set fallback values in SupabaseConfig or pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
