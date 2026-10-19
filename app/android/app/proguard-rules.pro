# Room databases are created by reflection through their generated _Impl
# class's no-argument constructor. R8 removes that constructor from
# WorkManager's database (pulled in by google_mobile_ads), and release builds
# then crash at launch: "NoSuchMethodException: WorkDatabase_Impl.<init>".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
