# flutter_local_notifications runtime components used in release builds.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Keep Flutter plugin registrant references used at startup.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
