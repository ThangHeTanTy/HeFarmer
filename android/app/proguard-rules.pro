# ===== Quy tắc giữ lại cần thiết cho Flutter (mọi thứ khác bị xáo trộn) =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core (Flutter deferred components tham chiếu tới, dù app không dùng)
-dontwarn com.google.android.play.core.**

# Giữ chú thích cho các plugin (geolocator, webview...)
-keepattributes *Annotation*
