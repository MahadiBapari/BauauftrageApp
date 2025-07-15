# Stripe SDK
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**

# React Native Stripe SDK (sometimes used by flutter_stripe)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.** 

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.stripe.** { *; }
-keep class com.reactnativestripesdk.** { *; }
-keep class com.flutter.stripe.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.stripe.**
-dontwarn com.reactnativestripesdk.**
-dontwarn com.flutter.stripe.**