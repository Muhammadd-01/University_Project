package com.childguard.childguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val EVENT_CHANNEL = "com.childguard.childguard/power_button"
    private val METHOD_CHANNEL = "com.childguard.childguard/sms"
    private var eventSink: EventChannel.EventSink? = null

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
                eventSink?.success("TRIPLE_PRESS")
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
                } else {
                    result.notImplemented()
                }
            }
    }
}
