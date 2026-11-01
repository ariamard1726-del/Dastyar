# قوانین حفظ کلاس‌ها برای ساخت انتشار (R8 / ProGuard)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.ariabod.dastyar.** { *; }
-dontwarn io.flutter.embedding.**
