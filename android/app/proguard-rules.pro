# Razorpay
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * { public void onPayment*(...); }
# Flutter local notifications (Gson)
-keep class com.dexterous.** { *; }
-keepattributes Signature
