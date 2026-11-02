# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Firebase & Google Play Services
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.firestore.** { *; }
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Desugaring / Guava / Protobuf / Play Core warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.android.play.core.**

# Geolocator & Google Play Services Location
-keep class com.baseflow.geolocator.** { *; }
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
