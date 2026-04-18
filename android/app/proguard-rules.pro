# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# App specific - Keep PanicService to prevent ClassNotFoundException in release mode
-keep class com.childguard.childguard.PanicService { *; }
-keep class com.childguard.childguard.MainActivity { *; }

# Play Core (Suppress warnings for missing classes referenced by Flutter Engine)
-dontwarn com.google.android.play.core.**
