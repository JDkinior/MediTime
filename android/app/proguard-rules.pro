# ProGuard / R8 Rules for MediTime

# Flutter Engine & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# MediTime Native Classes & Widgets
-keep class com.meditime.app.** { *; }
-keepclassmembers class com.meditime.app.** { *; }

# AndroidX WorkManager
-keep class androidx.work.** { *; }

# JDK Desugaring
-keep class j$.** { *; }

# Firebase & Play Services
-keepattributes *Annotation*
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Home Widget
-keep class es.antonborri.home_widget.** { *; }

# Google Play Core & SplitInstall (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
