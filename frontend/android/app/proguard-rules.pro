# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (for Flutter)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# HTML Editor Enhanced
-keep class com.htmleditor.** { *; }
-keep class android.webkit.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent obfuscation of input/output types for methods on classes that will be serialized
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}