package com.example.amaia

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL_SMS = "com.example.amaia.sms"
    private val CHANNEL_TASK = "com.example.amaia.task"
    private val SMS_PERMISSION_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para SMS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMS).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val message = call.argument<String>("message")
                    val recipients = call.argument<List<String>>("recipients")
                    
                    sendSMS(message, recipients, result)
                }
                "checkSMSPermission" -> {
                    val hasPermission = checkSMSPermission()
                    result.success(hasPermission)
                }
                "requestSMSPermission" -> {
                    requestSMSPermission()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Canal para tareas
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TASK).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTasks" -> {
                    getTasks(result)
                }
                "cancelAllTasks" -> {
                    cancelAllTasks(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun sendSMS(message: String?, recipients: List<String>?, result: MethodChannel.Result) {
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
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            var successCount = 0
            val errors = mutableListOf<String>()

            for (recipient in recipients) {
                try {
                    if (message.length > 160) {
                        // Para mensajes largos, dividir en partes
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

    private fun getTasks(result: MethodChannel.Result) {
        try {
            val workManager = WorkManager.getInstance(applicationContext)
            val workInfosFuture = workManager.getWorkInfosByTag("amaiaPeriodicTasks")
            
            val workInfos = workInfosFuture.get()
            val tasks = workInfos.map { workInfo ->
                mapOf(
                    "id" to workInfo.id.toString(),
                    "state" to workInfo.state.name,
                    "tags" to workInfo.tags.toList(),
                    "runAttemptCount" to workInfo.runAttemptCount
                )
            }
            result.success(tasks)
        } catch (e: Exception) {
            result.error("TASK_ERROR", "Error al obtener tareas: ${e.message}", null)
        }
    }

    private fun cancelAllTasks(result: MethodChannel.Result) {
        try {
            val workManager = WorkManager.getInstance(applicationContext)
            workManager.cancelAllWorkByTag("amaiaPeriodicTasks")
            result.success("Todas las tareas canceladas")
        } catch (e: Exception) {
            result.error("TASK_ERROR", "Error al cancelar tareas: ${e.message}", null)
        }
    }

    private fun checkSMSPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSMSPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            SMS_PERMISSION_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            SMS_PERMISSION_CODE -> {
                // Puedes notificar a Flutter sobre el resultado del permiso si es necesario
                val granted = grantResults.isNotEmpty() && 
                             grantResults[0] == PackageManager.PERMISSION_GRANTED
                
                // Opcional: enviar resultado a Flutter
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL_SMS).invokeMethod(
                        "onPermissionResult", 
                        mapOf("granted" to granted)
                    )
                }
            }
        }
    }
}