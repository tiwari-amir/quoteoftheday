import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppPerformanceTier { low, balanced, high }

@immutable
class DevicePerformanceProfile {
  const DevicePerformanceProfile({
    required this.tier,
    required this.isLowRamDevice,
    required this.memoryClassMb,
    required this.largeMemoryClassMb,
    required this.totalMemoryMb,
    required this.processorCount,
    required this.platformLabel,
  });

  factory DevicePerformanceProfile.balanced() {
    return const DevicePerformanceProfile(
      tier: AppPerformanceTier.balanced,
      isLowRamDevice: false,
      memoryClassMb: 192,
      largeMemoryClassMb: 256,
      totalMemoryMb: 4096,
      processorCount: 6,
      platformLabel: 'fallback',
    );
  }

  factory DevicePerformanceProfile.fromMap(Map<Object?, Object?> raw) {
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    final isLowRamDevice = map['isLowRamDevice'] == true;
    final memoryClassMb = _asInt(map['memoryClassMb'], fallback: 192);
    final largeMemoryClassMb = _asInt(
      map['largeMemoryClassMb'],
      fallback: memoryClassMb,
    );
    final totalMemoryMb = _asInt(map['totalMemoryMb'], fallback: 4096);
    final processorCount = _asInt(map['processorCount'], fallback: 6);

    final lowTier =
        isLowRamDevice ||
        totalMemoryMb <= 3072 ||
        memoryClassMb <= 192 ||
        processorCount <= 4;
    final highTier =
        !isLowRamDevice &&
        totalMemoryMb >= 6144 &&
        largeMemoryClassMb >= 256 &&
        processorCount >= 8;

    return DevicePerformanceProfile(
      tier: highTier
          ? AppPerformanceTier.high
          : lowTier
          ? AppPerformanceTier.low
          : AppPerformanceTier.balanced,
      isLowRamDevice: isLowRamDevice,
      memoryClassMb: memoryClassMb,
      largeMemoryClassMb: largeMemoryClassMb,
      totalMemoryMb: totalMemoryMb,
      processorCount: processorCount,
      platformLabel: map['platformLabel']?.toString() ?? 'android',
    );
  }

  final AppPerformanceTier tier;
  final bool isLowRamDevice;
  final int memoryClassMb;
  final int largeMemoryClassMb;
  final int totalMemoryMb;
  final int processorCount;
  final String platformLabel;

  bool get useLiteRendering => tier == AppPerformanceTier.low;
  bool get allowRichEntryAnimations => tier == AppPerformanceTier.high;
  bool get allowDecorativeBackgroundPainter => tier != AppPerformanceTier.low;

  int get startupWarmQuoteLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 72;
      case AppPerformanceTier.balanced:
        return 120;
      case AppPerformanceTier.high:
        return 180;
    }
  }

  int get primaryFeedLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 120;
      case AppPerformanceTier.balanced:
        return 180;
      case AppPerformanceTier.high:
        return 240;
    }
  }

  int get exploreDiscoveryLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 72;
      case AppPerformanceTier.balanced:
        return 120;
      case AppPerformanceTier.high:
        return 180;
    }
  }

  int get catalogQueryLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 240;
      case AppPerformanceTier.balanced:
        return 360;
      case AppPerformanceTier.high:
        return 600;
    }
  }

  int get searchResultLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 48;
      case AppPerformanceTier.balanced:
        return 72;
      case AppPerformanceTier.high:
        return 96;
    }
  }

  int get authorDiscoveryImageBudget {
    switch (tier) {
      case AppPerformanceTier.low:
        return 3;
      case AppPerformanceTier.balanced:
        return 8;
      case AppPerformanceTier.high:
        return 18;
    }
  }

  int get viewerCycleCacheLimit {
    switch (tier) {
      case AppPerformanceTier.low:
        return 2;
      case AppPerformanceTier.balanced:
        return 3;
      case AppPerformanceTier.high:
        return 4;
    }
  }

  int get imageCacheEntries {
    switch (tier) {
      case AppPerformanceTier.low:
        return 90;
      case AppPerformanceTier.balanced:
        return 140;
      case AppPerformanceTier.high:
        return 200;
    }
  }

  int get imageCacheBytes {
    switch (tier) {
      case AppPerformanceTier.low:
        return 32 * 1024 * 1024;
      case AppPerformanceTier.balanced:
        return 56 * 1024 * 1024;
      case AppPerformanceTier.high:
        return 96 * 1024 * 1024;
    }
  }

  static int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class DevicePerformanceService {
  static const MethodChannel _channel = MethodChannel(
    'com.hbp.quoteoftheday/device_performance',
  );

  Future<DevicePerformanceProfile> loadProfile() async {
    if (kIsWeb) {
      return DevicePerformanceProfile.balanced();
    }

    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'getProfile',
      );
      if (response == null || response.isEmpty) {
        return DevicePerformanceProfile.balanced();
      }
      return DevicePerformanceProfile.fromMap(response);
    } catch (_) {
      return DevicePerformanceProfile.balanced();
    }
  }
}
