import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_provider.dart';

final authBootstrapProvider = FutureProvider<void>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client.auth.currentSession != null) {
    return;
  }

  try {
    await client.auth.signInAnonymously().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Keep UI responsive even if auth/network is delayed.
  }
});
