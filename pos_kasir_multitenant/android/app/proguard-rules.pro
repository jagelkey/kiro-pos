# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Riverpod - State Management
-keep class * extends **StateNotifier { *; }
-keep class * extends **ChangeNotifier { *; }
-keepclassmembers class * extends **StateNotifier {
    public <methods>;
}
-keepclassmembers class * extends **ChangeNotifier {
    public <methods>;
}

# Keep all provider classes
-keep class **Provider { *; }
-keep class **Notifier { *; }

# Google Play Core (for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Keep model classes
-keep class com.posapp.pos_kasir_multitenant.** { *; }

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# General Android rules
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep all methods that might be called via reflection
-keepclassmembers class * {
    public <methods>;
}

# Ignore missing classes warnings
-ignorewarnings
