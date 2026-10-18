# Flutter ProGuard Rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep interface io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
-dontwarn io.flutter.plugins.**

# OpenVPN Flutter
-keep class id.laskarmedia.openvpn_flutter.** { *; }
-dontwarn id.laskarmedia.openvpn_flutter.**
