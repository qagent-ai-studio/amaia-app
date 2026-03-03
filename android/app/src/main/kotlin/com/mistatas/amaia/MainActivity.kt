package com.mistatas.amaia

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.WorkManager
import com.mistatas.amaia.ble.MkButtonChannel
import com.moko.support.d.DMokoSupport
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelSms  = "com.mistatas.amaia.sms"
    private val channelTask = "com.mistatas.amaia.task"
    private val smsPermissionCode = 100

    private lateinit var mkButtonChannel: MkButtonChannel

    // Un solo configureFlutterEngine con todos los canales
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal SMS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelSms)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSMS" -> {
                        val message    = call.argument<String>("message")
                        val recipients = call.argument<List<String>>("recipients")
                        sendSMS(message, recipients, result)
                    }
                    "checkSMSPermission"   -> result.success(checkSMSPermission())
                    "requestSMSPermission" -> { requestSMSPermission(); result.success(null) }
                    else                   -> result.notImplemented()
                }
            }

        // Canal tareas
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelTask)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTasks"        -> getTasks(result)
                    "cancelAllTasks"  -> cancelAllTasks(result)
                    else              -> result.notImplemented()
                }
            }

        // Canal MK Button BLE
        val bleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MkButtonChannel.CHANNEL_NAME,
        )
        mkButtonChannel = MkButtonChannel(
            context = applicationContext,
            channel = bleChannel,
        )
        bleChannel.setMethodCallHandler(mkButtonChannel)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // XLog requerido por MKBleLib antes de cualquier operación BLE
    com.elvishew.xlog.XLog.init(com.elvishew.xlog.LogLevel.NONE)

    DMokoSupport.getInstance().init(applicationContext)
    mkButtonChannel.register()
}

    override fun onDestroy() {
        mkButtonChannel.unregister()
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // SMS
    // -------------------------------------------------------------------------

    private fun sendSMS(
        message: String?,
        recipients: List<String>?,
        result: MethodChannel.Result,
    ) {
        try {
            if (message == null || recipients == null) {
                result.error("INVALID_ARGUMENTS", "Mensaje o destinatarios no válidos", null)
                return
            }
            if (!checkSMSPermission()) {
                result.error("PERMISSION_DENIED", "Permisos SMS no otorgados", null)
                return
            }
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            var successCount = 0
            val errors = mutableListOf<String>()
            for (recipient in recipients) {
                try {
                    if (message.length > 160) {
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
                    } else {
                        smsManager.sendTextMessage(recipient, null, message, null, null)
                    }
                    successCount++
                } catch (e: Exception) {
                    errors.add("Error enviando a $recipient: ${e.message}")
                }
            }
            if (errors.isEmpty()) {
                result.success("SMS enviado exitosamente a $successCount destinatarios")
            } else {
                result.success("SMS enviado a $successCount destinatarios. Errores: ${errors.joinToString("; ")}")
            }
        } catch (e: Exception) {
            result.error("SMS_ERROR", "Error general al enviar SMS: ${e.message}", null)
        }
    }

    private fun checkSMSPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
                PackageManager.PERMISSION_GRANTED

    private fun requestSMSPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            smsPermissionCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsPermissionCode) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, channelSms)
                    .invokeMethod("onPermissionResult", mapOf("granted" to granted))
            }
        }
    }

    // -------------------------------------------------------------------------
    // WorkManager tasks
    // -------------------------------------------------------------------------

    private fun getTasks(result: MethodChannel.Result) {
        try {
            val workInfos = WorkManager.getInstance(applicationContext)
                .getWorkInfosByTag("amaiaPeriodicTasks")
                .get()
            val tasks = workInfos.map { info ->
                mapOf(
                    "id"              to info.id.toString(),
                    "state"           to info.state.name,
                    "tags"            to info.tags.toList(),
                    "runAttemptCount" to info.runAttemptCount,
                )
            }
            result.success(tasks)
        } catch (e: Exception) {
            result.error("TASK_ERROR", "Error al obtener tareas: ${e.message}", null)
        }
    }

    private fun cancelAllTasks(result: MethodChannel.Result) {
        try {
            WorkManager.getInstance(applicationContext)
                .cancelAllWorkByTag("amaiaPeriodicTasks")
            result.success("Todas las tareas canceladas")
        } catch (e: Exception) {
            result.error("TASK_ERROR", "Error al cancelar tareas: ${e.message}", null)
        }
    }
}