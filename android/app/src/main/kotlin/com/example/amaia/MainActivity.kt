package com.example.amaia
import android.telephony.SmsManager
import androidx.work.WorkManager
import androidx.work.WorkInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL_SMS = "com.example.amaia.sms"
    private val CHANNEL_TASK = "com.example.amaia.task"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMS).setMethodCallHandler { call, result ->
            if (call.method == "sendSMS") {
                val message = call.argument<String>("message")
                val recipients = call.argument<List<String>>("recipients")

                try {
                    if (message != null && recipients != null) {
                        val smsManager = SmsManager.getDefault()
                        for (recipient in recipients) {
                            smsManager.sendTextMessage(recipient, null, message, null, null)
                        }
                        result.success("SMS enviado exitosamente")
                    } else {
                        result.error("INVALID_ARGUMENTS", "Mensaje o destinatarios no válidos", null)
                    }
                } catch (e: Exception) {
                    result.error("SMS_ERROR", "Error al enviar SMS: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TASK).setMethodCallHandler { call, result ->
            if (call.method == "getTasks") {
                val workManager = WorkManager.getInstance(applicationContext)
                val workInfos = workManager.getWorkInfosByTag("amaiaPeriodicTasks").get()

                val tasks = workInfos.map {
                    mapOf(
                        "id" to it.id.toString(),
                        "state" to it.state.name
                    )
                }
                result.success(tasks)
            } else {
                result.notImplemented()
            }
        }
    }
}