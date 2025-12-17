# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.database.** { *; }
-keep class com.google.firebase.database.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Database (Realtime Database)
-keep class com.google.firebase.database.** { *; }
-keepclassmembers class com.google.firebase.database.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# SQLite
-keep class io.flutter.plugins.sqflite.** { *; }

# HTTP (http package için)
-keep class dart.io.** { *; }
-keep class dart.async.** { *; }
-keep class dart.core.** { *; }
-keep class dart.convert.** { *; }
-keep class dart.typed_data.** { *; }
-keep class dart.collection.** { *; }
-keep class dart.math.** { *; }

# HTTP package (http.dart)
-keep class io.flutter.plugins.** { *; }
-dontwarn okhttp3.**
-dontwarn javax.annotation.**

# HTTP (okhttp3 için - eğer kullanılıyorsa)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Gson (Firebase için)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Dart classes (reflection için)
-keep class dart.** { *; }
-keep class * extends dart.core.Object { *; }

# Google Play Core (Flutter deferred components için - kullanılmıyor ama R8 hata veriyor)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

