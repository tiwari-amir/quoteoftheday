import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_performance_service.dart';

final appPerformanceProfileProvider = Provider<DevicePerformanceProfile>((ref) {
  return DevicePerformanceProfile.balanced();
});
