# ProGuard rules for Прогулкин
# Add project specific ProGuard rules here.

# Keep Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep pedometer
-keep class com.stephenbrawn.pedometer.** { *; }

# Keep local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep image compression
-keep class com.example.flutterimagecompress.** { *; }

# Keep share_plus
-keep class io.github.ponnamkarthik.toast.fluttertoast.** { *; }

# Keep permission handler
-keep class com.irbaseflow.permissionhandler.** { *; }

# General rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
