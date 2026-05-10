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
                } else if (call.method == "isAccessibilityServiceEnabled") {
                    result.success(isAccessibilityServiceEnabled())
                } else if (call.method == "openAccessibilitySettings") {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                } else if (call.method == "isNumberOnWhatsApp") {
                    val phone = call.argument<String>("phone")
                    if (phone != null) {
                        result.success(isNumberOnWhatsApp(phone))
                    } else {
                        result.error("INVALID", "Phone is null", null)
                    }
                } else if (call.method == "getDevicePhoneNumber") {
                    result.success(getDevicePhoneNumber())
                } else {
                    result.notImplemented()
                }
            }
    }

    @SuppressLint("HardwareIds", "MissingPermission")
    private fun getDevicePhoneNumber(): String? {
        return try {
            val tMgr = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            tMgr.line1Number
        } catch (e: Exception) {
            null
        }
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

    private fun isNumberOnWhatsApp(phoneNumber: String): Boolean {
        val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(phoneNumber))
        val projection = arrayOf(ContactsContract.PhoneLookup._ID, ContactsContract.PhoneLookup.NUMBER)
        val cursor = contentResolver.query(uri, projection, null, null, null)
        
        var isOnWhatsApp = false
        cursor?.use {
            if (it.moveToFirst()) {
                val contactId = it.getString(it.getColumnIndexOrThrow(ContactsContract.PhoneLookup._ID))
                val dataUri = ContactsContract.Data.CONTENT_URI
                val dataProjection = arrayOf(ContactsContract.Data.MIMETYPE)
                val dataSelection = "${ContactsContract.Data.CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?"
                val dataSelectionArgs = arrayOf(contactId, "vnd.android.cursor.item/vnd.com.whatsapp.profile")
                
                val dataCursor = contentResolver.query(dataUri, dataProjection, dataSelection, dataSelectionArgs, null)
                dataCursor?.use { dc ->
                    if (dc.count > 0) {
                        isOnWhatsApp = true
                    }
                }
            }
        }
        return isOnWhatsApp
    }
}
