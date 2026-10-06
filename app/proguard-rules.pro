# Hermes client ProGuard rules

# Retrofit
-keepattributes Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations, AnnotationDefault
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson / models
-keepclassmembers class com.hermes.client.data.remote.dto.** { *; }
-keep class com.hermes.client.data.remote.dto.** { *; }
# These are (de)serialised by Gson inside Room TypeConverters too.
-keep class com.hermes.client.data.model.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn com.google.gson.**

# Room
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.paging.**

# Hilt
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }

# Kotlin metadata
-keep class kotlin.Metadata { *; }
