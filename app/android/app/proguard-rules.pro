# Room databases are created by reflection through their generated _Impl
# class's no-argument constructor. R8 removes that constructor from
# WorkManager's database (pulled in by google_mobile_ads), and release builds
# then crash at launch: "NoSuchMethodException: WorkDatabase_Impl.<init>".
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# shared_preferences_android 2.5 calls SharedPreferencesApiRegistrar's
# suspend methods from Dart through JNI (package:jni), looking up the
# Kotlin coroutine classes by name. R8 renames or removes them, and release
# builds lose all saved scores and settings ("NoSuchMethodError ...
# SharedPreferencesApiRegistrar.getAll", "ClassNotFoundException:
# kotlin/coroutines/intrinsics/CoroutineSingletons").
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
