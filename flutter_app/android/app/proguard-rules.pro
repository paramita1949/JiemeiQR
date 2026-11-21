# AMap Location AAR references optional GNSS classes not shipped in the SDK package.
# Keep release minification working while preserving runtime behavior.
-dontwarn com.amap.ams.gnss.**

# flutter_local_notifications 17.2.4 reads its scheduled cache through Gson TypeToken.
# R8 full mode needs both the Signature attribute and retained token classes.
# Without these rules, pending/cancel/schedule fail with "Missing type parameter".
-keepattributes Signature
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
