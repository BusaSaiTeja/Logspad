# Flutter Local Notifications ProGuard / R8 Rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.window.** { *; }

# Desugaring and Timezone keep rules
-keep class java.time.** { *; }
-keep class j$.time.** { *; }
