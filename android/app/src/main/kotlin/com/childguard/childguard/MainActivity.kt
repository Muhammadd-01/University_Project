// ============================================
// MainActivity.kt - Android Native Code (Power Button Detection)
// ============================================
// Yeh Kotlin file Android ka native code hai
// Flutter mein direct power button detect nahi hota, isliye native code zaroori hai
//
// KAISE KAAM KARTA HAI:
// 1. Jab user power button dabata hai toh screen ON ya OFF hoti hai
// 2. Android humes ACTION_SCREEN_OFF aur ACTION_SCREEN_ON events bhejta hai
// 3. Hum in events ko BroadcastReceiver se sunte hain
// 4. Agar 2 baar screen off ho 1.5 second ke andar toh "DOUBLE_PRESS" maan lete hain
// 5. EventChannel se Flutter ko "DOUBLE_PRESS" event bhejte hain
// 6. Flutter mein panic alert trigger hota hai
//
// LIMITATION (VIVA MEIN BATANA):
// - Yeh sirf tab kaam karega jab app foreground mein ho ya recently background mein gayi ho
// - Agar Android system app ko kill kar de toh receiver bhi mar jayega
// - Proper solution ke liye Foreground Service chahiye (notification wali) jo complex hai
// - Humne simple rakha hai - sirf MainActivity mein register kiya hai
//
// EventChannel vs MethodChannel:
// - MethodChannel: ek baar data bhejne ke liye (request-response)
// - EventChannel: continuous stream of events ke liye (hum yeh use kar rahe hain)

package com.childguard.childguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    // Channel ka naam - yeh SAME hona chahiye jo Flutter side pe hai (panic_screen.dart mein)
    private val CHANNEL = "com.childguard.childguard/power_button"

    // BroadcastReceiver - Android ke system events sunta hai
    private var screenReceiver: BroadcastReceiver? = null

    // EventSink - isse Flutter ko events bhejte hain
    private var eventSink: EventChannel.EventSink? = null

    // Last screen OFF ka time (milliseconds mein)
    // System.currentTimeMillis() se current time milta hai
    private var lastScreenOffTime: Long = 0

    // Double press ka threshold - 1500 milliseconds (1.5 second)
    // Agar 2 baar screen off ho 1.5 second ke andar toh double press hai
    private val DOUBLE_PRESS_THRESHOLD = 1500L

    // Screen off kitni baar hua count karo
    private var pressCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Start the background service
        val serviceIntent = Intent(this, PanicService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    // Since the service is doing the heavy lifting, we'll just listen for results
    // if the app needs to show UI feedback. For now, the service handles Firestore.
}
