import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import 'quote_providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final notificationService = ref.read(notificationServiceProvider);
  await notificationService.initialize();

  final quotes = await ref.watch(allQuotesProvider.future);
  await notificationService.scheduleMorningQuotes(quotes);
});
