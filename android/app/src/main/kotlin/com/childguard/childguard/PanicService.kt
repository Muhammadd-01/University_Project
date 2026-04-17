package com.childguard.childguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase

class PanicService : Service() {
    private var screenReceiver: BroadcastReceiver? = null
    private var lastOffTime: Long = 0
    private var pressCount = 0
    private val CHANNEL_ID = "PanicServiceChannel"

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
                if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                    val now = System.currentTimeMillis()
                    if (now - lastOffTime < 1500) {
                        pressCount++
                        if (pressCount >= 3) {
                            sendPanicAlert()
                            pressCount = 0
                        }
                    } else {
                        pressCount = 1
                    }
                    lastOffTime = now
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenReceiver, filter)
    }

    private fun sendPanicAlert() {
        // Read data from SharedPreferences (Saved from Flutter)
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val uid = prefs.getString("flutter.uid", null)
        val parentId = prefs.getString("flutter.parentId", null)

        if (uid != null && parentId != null) {
            val alert = hashMapOf(
                "type" to "panic",
                "senderId" to uid,
                "parentId" to parentId,
                "message" to "🚨 BACKGROUND EMERGENCY! Power button triple-pressed!",
                "timestamp" to com.google.firebase.Timestamp.now()
            )
            Firebase.firestore.collection("alerts").add(alert)
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
