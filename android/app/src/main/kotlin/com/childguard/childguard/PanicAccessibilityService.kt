package com.childguard.childguard

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.Timestamp

class PanicAccessibilityService : AccessibilityService() {

    private var isVolUpPressed = false
    private var isVolDownPressed = false
    private var lastTriggerTime: Long = 0
    private var volPressCount = 0
    private var lastVolPressTime: Long = 0
    private val MULTI_PRESS_THRESHOLD = 1500L // 1.5 seconds for multi-press
    private val COOLDOWN_PERIOD = 5000L // 5 seconds cooldown between panics
    private val TAG = "PanicAccessibility"

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val action = event.action

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (action == KeyEvent.ACTION_DOWN) {
                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolUpPressed = true
                if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolDownPressed = true

                val now = System.currentTimeMillis()

                // Check 1: Both Volume Buttons Pressed Simultaneously
                if (isVolUpPressed && isVolDownPressed) {
                    if (now - lastTriggerTime > COOLDOWN_PERIOD) {
                        triggerPanic()
                        lastTriggerTime = now
                        volPressCount = 0 // Reset counter
                    }
                } 
                // Check 2: Any Volume Button pressed multiple times quickly (3 times)
                else {
                    if (now - lastVolPressTime > MULTI_PRESS_THRESHOLD) {
                        volPressCount = 1 // Reset if too much time passed
                    } else {
                        volPressCount++
                        if (volPressCount >= 3) {
                            if (now - lastTriggerTime > COOLDOWN_PERIOD) {
                                triggerPanic()
                                lastTriggerTime = now
                            }
                            volPressCount = 0 // Reset after trigger
                        }
                    }
                    lastVolPressTime = now
                }

            } else if (action == KeyEvent.ACTION_UP) {
                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolUpPressed = false
                if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolDownPressed = false
            }
            
            return false // Let volume event pass through
        }
        return super.onKeyEvent(event)
    }

    private fun triggerPanic() {
        Log.d(TAG, "Panic Triggered via Volume Buttons!")
        
        // 1. Send broadcast for UI if app is open
        val broadcastIntent = Intent("com.childguard.PANIC_TRIGGERED")
        broadcastIntent.putExtra("trigger", "VOLUME_BUTTONS")
        sendBroadcast(broadcastIntent)

        // 2. Send directly to Firestore so parent wakes up even if app is closed
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val uid = prefs.getString("flutter.uid", null)
        val parentId = prefs.getString("flutter.parentId", null)

        if (uid != null && parentId != null) {
            val alert = hashMapOf(
                "type" to "panic",
                "senderId" to uid,
                "parentId" to parentId,
                "message" to "🚨 EMERGENCY! Child triggered panic via Volume Buttons!",
                "timestamp" to Timestamp.now()
            )
            
            try {
                Firebase.firestore.collection("alerts").add(alert)
                    .addOnSuccessListener { 
                        Log.d(TAG, "Panic alert sent to Firestore")
                        // 3. WAKE UP CHILD DEVICE TOO
                        launchMainActivity("panic", "🚨 Emergency alert sent to parent!")
                    }
                    .addOnFailureListener { e -> Log.e(TAG, "Failed to send panic alert", e) }
            } catch (e: Exception) {
                Log.e(TAG, "Firestore error: ${e.message}")
            }
        } else {
            Log.w(TAG, "Cannot send panic: uid or parentId is null")
            // Launch app anyway so user can see they aren't linked/logged in
            launchMainActivity("error", "Cannot send panic: Device not properly linked!")
        }
    }

    private fun launchMainActivity(type: String, message: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger", "DANGER")
            putExtra("alertType", type)
            putExtra("alertMessage", message)
        }
        try {
            startActivity(intent)
            Log.d(TAG, "Launched MainActivity from Accessibility Service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch activity: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            FirebaseApp.initializeApp(this)
        } catch (e: Exception) {
            Log.e(TAG, "Firebase init failed: ${e.message}")
        }
        Log.d(TAG, "Accessibility Service Connected and Firebase Initialized")
    }
}
