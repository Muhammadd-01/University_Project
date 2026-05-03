package com.childguard.childguard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase

class PanicService : Service() {
    private var screenReceiver: BroadcastReceiver? = null
    private var lastOffTime: Long = 0
    private var pressCount = 0
    private val CHANNEL_ID = "PanicServiceChannel"
    private val TAG = "PanicService"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ChildGuard Active")
            .setContentText("Panic detection is running in background")
            .setSmallIcon(android.R.drawable.ic_notification_overlay)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(1, notification)
        registerScreenReceiver()
    }

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action
                if (action == Intent.ACTION_SCREEN_OFF || action == Intent.ACTION_SCREEN_ON) {
                    val now = System.currentTimeMillis()
                    if (now - lastOffTime < 1500) {
                        pressCount++
                        if (pressCount == 3 || pressCount == 4) {
                            sendPanicAlert(pressCount)
                            sendEmergencySms()
                            // Broadcast to MainActivity if app is in foreground
                            val broadcastIntent = Intent("com.childguard.PANIC_TRIGGERED")
                            broadcastIntent.putExtra("count", pressCount)
                            sendBroadcast(broadcastIntent)
                        }
                        if (pressCount >= 4) pressCount = 0
                    } else {
                        pressCount = 1
                    }
                    lastOffTime = now
                }
            }
        }
        val filter = IntentFilter()
        filter.addAction(Intent.ACTION_SCREEN_OFF)
        filter.addAction(Intent.ACTION_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    private fun sendPanicAlert(count: Int) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val uid = prefs.getString("flutter.uid", null)
        val parentId = prefs.getString("flutter.parentId", null)

        if (uid != null && parentId != null) {
            val alert = hashMapOf(
                "type" to "panic",
                "senderId" to uid,
                "parentId" to parentId,
                "message" to "🚨 EMERGENCY! Power button tapped $count times!",
                "timestamp" to com.google.firebase.Timestamp.now()
            )
            Firebase.firestore.collection("alerts").add(alert)
        }
    }

    private fun sendEmergencySms() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val parentId = prefs.getString("flutter.parentId", null) ?: return

        // Fetch emergency contacts from Firestore and send SMS
        Firebase.firestore.collection("users").document(parentId).get()
            .addOnSuccessListener { doc ->
                val contacts = doc.get("emergencyContacts") as? List<Map<String, Any>> ?: return@addOnSuccessListener
                val message = "🚨 CHILDGUARD EMERGENCY!\nThis is an automated emergency alert triggered by power button.\nPlease respond immediately!"

                try {
                    val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }

                    for (contact in contacts) {
                        val phone = (contact["phone"] as? String)?.replace(Regex("[^+0-9]"), "") ?: continue
                        try {
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            Log.d(TAG, "SMS sent to $phone")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to send SMS to $phone: ${e.message}")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "SMS Manager error: ${e.message}")
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to fetch contacts: ${e.message}")
            }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Panic Detection Service", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        super.onDestroy()
    }
}
