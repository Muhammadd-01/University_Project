package com.childguard.childguard

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class PanicAccessibilityService : AccessibilityService() {

    private var isVolUpPressed = false
    private var isVolDownPressed = false
    private var longPressStartTime: Long = 0
    private val LONG_PRESS_THRESHOLD = 2000L // 2 seconds
    private val TAG = "PanicAccessibility"

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val action = event.action

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (action == KeyEvent.ACTION_DOWN) {
                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolUpPressed = true
                if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolDownPressed = true

                if (isVolUpPressed && isVolDownPressed) {
                    if (longPressStartTime == 0L) {
                        longPressStartTime = System.currentTimeMillis()
                    } else if (System.currentTimeMillis() - longPressStartTime >= LONG_PRESS_THRESHOLD) {
                        triggerPanic()
                        longPressStartTime = 0L // Reset to prevent multiple triggers
                    }
                }
            } else if (action == KeyEvent.ACTION_UP) {
                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolUpPressed = false
                if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolDownPressed = false
                longPressStartTime = 0L
            }
            
            // Return true to consume the volume event during long press? 
            // Better to let it pass through unless we are sure, but for panic we might want to silence it.
            // For now, let it pass so volume still works normally.
            return false
        }
        return super.onKeyEvent(event)
    }

    private fun triggerPanic() {
        Log.d(TAG, "Panic Triggered via Volume Buttons!")
        val intent = Intent("com.childguard.PANIC_TRIGGERED")
        intent.putExtra("trigger", "VOLUME_BUTTONS")
        sendBroadcast(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service Connected")
    }
}
