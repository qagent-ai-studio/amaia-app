# EventBus: mantener métodos @Subscribe (usan reflexión)
-keepattributes *Annotation*
-keepclassmembers class ** {
    @org.greenrobot.eventbus.Subscribe <methods>;
}
-keep enum org.greenrobot.eventbus.ThreadMode { *; }

# EventBus subscriber index (si se usa generación en tiempo de compilación)
-keepclassmembers class * extends org.greenrobot.eventbus.util.ThrowableFailureEvent {
    <init>(java.lang.Throwable);
}

# MokoSmart SDK: mantener clases y métodos usados por reflexión
-keep class com.moko.** { *; }
-keep class no.nordicsemi.** { *; }
-keep class com.moko.ble.lib.event.** { *; }
-keep class com.moko.support.d.** { *; }

# Nuestras clases BLE (mantener nombres para que EventBus las encuentre)
-keep class com.mistatas.amaia.ble.MkButtonChannel { *; }
-keep class com.mistatas.amaia.ble.MkButtonBackgroundService { *; }

# Mantener info de líneas para stack traces legibles
-keepattributes SourceFile,LineNumberTable
