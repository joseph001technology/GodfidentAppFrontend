# ── flutter_local_notifications ────────────────────────────────────────────
# The plugin stores scheduled notifications with Gson. R8 strips the generic
# signature Gson reads from `new TypeToken<...>(){}`, which crashed every
# cancel()/zonedSchedule() call with:
#   IllegalStateException: TypeToken must be created with a type argument
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ── Godfident native services (referenced from the manifest / by name) ─────
-keep class com.example.godfident_flutter.** { *; }

# ── just_audio_background / audio_service ──────────────────────────────────
-keep class com.ryanheise.** { *; }
