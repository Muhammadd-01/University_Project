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

    // configureFlutterEngine() - Jab Flutter engine ready ho toh yeh call hota hai
    // Yahan hum EventChannel setup karte hain
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel banao - Flutter se communication ke liye
        // binaryMessenger: Flutter aur native ke beech data bhejne ka raasta
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                // onListen() - Jab Flutter EventChannel sunna shuru kare
                // Yahan receiver register karte hain
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events // EventSink save karo (baad mein events bhejne ke liye)
                    registerScreenReceiver() // Screen ON/OFF receiver register karo
                }

                // onCancel() - Jab Flutter sunna band kare
                // Yahan receiver unregister karte hain
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterScreenReceiver()
                }
            })
    }

    // registerScreenReceiver() - Screen ON/OFF events sunne ke liye receiver register karo
    // Yeh dynamically register hota hai (programmatically, AndroidManifest mein nahi)
    // Kyunke Android security ke liye SCREEN_ON/OFF manifest mein allow nahi karta
    private fun registerScreenReceiver() {
        // Naya BroadcastReceiver banao
        screenReceiver = object : BroadcastReceiver() {
            // onReceive() - Jab koi screen event aaye toh yeh call hota hai
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    // ===== SCREEN OFF EVENT =====
                    // Jab user power button dabaye aur screen band ho
                    Intent.ACTION_SCREEN_OFF -> {
                        val currentTime = System.currentTimeMillis()

                        // Check karo pichle screen off se kitna time hua
                        if (currentTime - lastScreenOffTime < DOUBLE_PRESS_THRESHOLD) {
                            // 1.5 second ke andar dobara screen off hua!
                            pressCount++

                            // Agar 2 ya zyada baar hua toh DOUBLE PRESS hai
                            if (pressCount >= 2) {
                                // Flutter ko "DOUBLE_PRESS" event bhejo
                                // eventSink?.success() se data Flutter ke EventChannel pe jayega
                                eventSink?.success("DOUBLE_PRESS")
                                pressCount = 0 // Counter reset karo
                            }
                        } else {
                            // Pehli baar screen off hua (ya bahut der baad)
                            pressCount = 1
                        }

                        // Current time save karo next comparison ke liye
                        lastScreenOffTime = currentTime
                    }

                    // ===== SCREEN ON EVENT =====
                    // Jab screen on ho - hum sirf track kar rahe hain, kuch karna nahi
                    Intent.ACTION_SCREEN_ON -> {
                        // Screen on hone pe kuch nahi karna
                        // Sirf screen off events se double press detect karte hain
                    }
                }
            }
        }

        // IntentFilter banao - kaunse events sunne hain
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF) // Screen band hone ka event
            addAction(Intent.ACTION_SCREEN_ON)  // Screen on hone ka event
        }

        // Receiver register karo system ke saath
        registerReceiver(screenReceiver, filter)
    }

    // unregisterScreenReceiver() - Receiver unregister karo
    // Zaroori hai taake memory leak na ho
    // Agar register kiya hai toh unregister bhi karna zaroori hai
    private fun unregisterScreenReceiver() {
        screenReceiver?.let {
            try {
                unregisterReceiver(it) // System se unregister karo
            } catch (e: Exception) {
                // Agar already unregistered hai toh exception ignore karo
            }
            screenReceiver = null
        }
    }

    // onDestroy() - Jab Activity destroy ho (app band ho)
    // Yahan cleanup karte hain - receiver unregister karo
    override fun onDestroy() {
        unregisterScreenReceiver()
        super.onDestroy()
    }
}
