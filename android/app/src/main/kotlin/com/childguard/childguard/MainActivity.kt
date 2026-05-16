package com.childguard.childguard

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.text.TextUtils
import android.provider.ContactsContract
import android.net.Uri

class MainActivity : FlutterActivity() {

    private val EVENT_CHANNEL = "com.childguard.childguard/power_button"
    private val METHOD_CHANNEL = "com.childguard.childguard/sms"
    private var eventSink: EventChannel.EventSink? = null
    private var initialAlert: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Start the background service
        val serviceIntent = Intent(this, PanicService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // Listen for power button events from service
        val panicReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val trigger = intent?.getStringExtra("trigger") ?: "TRIPLE_PRESS"
                eventSink?.success(trigger)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(panicReceiver, IntentFilter("com.childguard.PANIC_TRIGGERED"), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(panicReceiver, IntentFilter("com.childguard.PANIC_TRIGGERED"))
        }

        // EventChannel for power button events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // MethodChannel for sending SMS from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendSms") {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            Log.d("ChildGuard", "SMS sent to $phone")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("ChildGuard", "SMS failed: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID", "Phone or message is null", null)
                    }
                } else if (call.method == "startService") {
                    val serviceIntent = Intent(this, PanicService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                } else if (call.method == "isAccessibilityServiceEnabled") {
                    result.success(isAccessibilityServiceEnabled())
                } else if (call.method == "openAccessibilitySettings") {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                } else if (call.method == "stopVibration") {
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                        vibrator.cancel()
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        notificationManager.cancel(100) // Panic Alert ID
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("ChildGuard", "Stop vibration failed: ${e.message}")
                        result.success(false)
                    }
                } else if (call.method == "bringToForeground") {
                    bringToForeground()
                    result.success(true)
                } else if (call.method == "getInitialAlert") {
                    result.success(initialAlert)
                    initialAlert = null // Clear after use
                } else {
                    result.notImplemented()
                }
            }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getStringExtra("trigger") == "DANGER") {
            val type = intent.getStringExtra("alertType") ?: "panic"
            val message = intent.getStringExtra("alertMessage") ?: "Emergency detected!"
            val alertId = intent.getStringExtra("alertId")
            initialAlert = mapOf("type" to type, "message" to message, "alertId" to alertId ?: "")
            
            // Trigger Flutter event if listener is active
            eventSink?.success("DANGER|$type|$message|$alertId")
        }
    }

    private fun bringToForeground() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "$packageName/${PanicAccessibilityService::class.java.canonicalName}"
        val enabled = Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
        if (enabled == 1) {
            val settingValue = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            if (settingValue != null) {
                val splitter = TextUtils.SimpleStringSplitter(':')
                splitter.setString(settingValue)
                while (splitter.hasNext()) {
                    val accessibilityService = splitter.next()
                    if (accessibilityService.equals(service, ignoreCase = true)) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
