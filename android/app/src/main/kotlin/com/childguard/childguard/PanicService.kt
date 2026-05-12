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
import com.google.firebase.Timestamp
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import android.location.Location

class PanicService : Service() {
    private var screenReceiver: BroadcastReceiver? = null
    private var lastOffTime: Long = 0
    private var pressCount = 0
    private val CHANNEL_ID = "PanicServiceChannel"
    private val TAG = "PanicService"

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var locationCallback: LocationCallback? = null
    private var lastBoundaryAlertTime: Long = 0

    override fun onCreate() {
        super.onCreate()
        try {
            com.google.firebase.FirebaseApp.initializeApp(this)
        } catch (e: Exception) {
            Log.e(TAG, "Firebase init failed: ${e.message}")
        }
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ChildGuard Active")
            .setContentText("Background safety monitoring is running")
            .setSmallIcon(android.R.drawable.ic_notification_overlay)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(1, notification)
        registerScreenReceiver()
        startAlertListenerIfParent()
        startChildLocationTracking()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand called")
        // Always refresh listeners to pick up new UID/role/parentId from SharedPreferences
        startAlertListenerIfParent()
        startChildLocationTracking()
        return START_STICKY
    }

    private var lastAlertId: String? = null
    private var alertListenerRegistration: com.google.firebase.firestore.ListenerRegistration? = null

    private fun startAlertListenerIfParent() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val role = prefs.getString("flutter.role", null)
        val uid = prefs.getString("flutter.uid", null)

        if (role == "parent" && uid != null) {
            Log.d(TAG, "Starting background alert listener for parent: $uid")
            
            alertListenerRegistration?.remove()
            
            alertListenerRegistration = Firebase.firestore.collection("alerts")
                .whereEqualTo("parentId", uid)
                .orderBy("timestamp", com.google.firebase.firestore.Query.Direction.DESCENDING)
                .limit(1)
                .addSnapshotListener { snapshot, e ->
                    if (e != null) {
                        Log.e(TAG, "Firestore listen failed: ${e.message}")
                        return@addSnapshotListener
                    }

                    if (snapshot != null && !snapshot.isEmpty) {
                        val doc = snapshot.documents[0]
                        val docId = doc.id
                        
                        // Prevent re-processing the same alert
                        if (docId == lastAlertId) return@addSnapshotListener
                        lastAlertId = docId

                        val alert = doc.data
                        val timestamp = doc.getTimestamp("timestamp")
                        
                        // Relaxed check: Only trigger if alert is from the last 2 minutes
                        val now = com.google.firebase.Timestamp.now().seconds
                        if (alert != null && timestamp != null && (now - timestamp.seconds) < 120) {
                            val type = alert["type"] as? String ?: "panic"
                            val message = alert["message"] as? String ?: "Emergency detected!"
                            Log.d(TAG, "New alert received: $type - $message")
                            showHighPriorityNotification(type, message)
                            
                            // FORCE OPEN: If we have permission to draw over apps, launch MainActivity directly
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || android.provider.Settings.canDrawOverlays(this)) {
                                launchMainActivity(type, message)
                            }
                        }
                    }
                }
        }
    }

    private fun startChildLocationTracking() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val role = prefs.getString("flutter.role", null)
        val uid = prefs.getString("flutter.uid", null)
        val parentId = prefs.getString("flutter.parentId", null)

        if (role == "child" && uid != null && parentId != null) {
            Log.d(TAG, "Starting native background location tracking for child")
            
            val locationRequest = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 3 * 60 * 1000) // 3 minutes
                .setMinUpdateIntervalMillis(60 * 1000) // 1 minute fastest
                .setMinUpdateDistanceMeters(50f) // 50 meters movement
                .build()
                
            locationCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    locationResult.lastLocation?.let { location ->
                        Log.d(TAG, "Background location update: ${location.latitude}, ${location.longitude}")
                        
                        // 1. Update location in Firestore
                        Firebase.firestore.collection("users").document(uid).update(
                            "latitude", location.latitude,
                            "longitude", location.longitude
                        ).addOnFailureListener { Log.e(TAG, "Failed to update location") }
                        
                        // 2. Check Boundary
                        checkSafeZones(location, uid, parentId)
                    }
                }
            }
            
            try {
                locationCallback?.let {
                    fusedLocationClient.requestLocationUpdates(locationRequest, it, android.os.Looper.getMainLooper())
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Missing location permission: ${e.message}")
            }
        }
    }

    private fun checkSafeZones(location: Location, childId: String, parentId: String) {
        // 5 minutes cooldown for boundary alerts
        if (System.currentTimeMillis() - lastBoundaryAlertTime < 5 * 60 * 1000) return
        
        Firebase.firestore.collection("users").document(parentId).collection("safeZones").get()
            .addOnSuccessListener { snapshot ->
                if (snapshot.isEmpty) return@addOnSuccessListener
                
                var isInsideAny = false
                var minDistance = Float.MAX_VALUE
                
                for (doc in snapshot.documents) {
                    val lat = doc.getDouble("lat") ?: continue
                    val lng = doc.getDouble("lng") ?: continue
                    val radius = doc.getDouble("radius") ?: continue
                    
                    val results = FloatArray(1)
                    Location.distanceBetween(location.latitude, location.longitude, lat, lng, results)
                    val distance = results[0]
                    
                    if (distance <= radius) {
                        isInsideAny = true
                        break
                    }
                    if (distance < minDistance) minDistance = distance
                }
                
                if (!isInsideAny) {
                    Log.d(TAG, "Child is outside safe zones! Distance: $minDistance")
                    lastBoundaryAlertTime = System.currentTimeMillis()
                    
                    val alert = hashMapOf(
                        "type" to "boundary",
                        "senderId" to childId,
                        "parentId" to parentId,
                        "message" to "⚠️ Child is outside all safe zones! Closest zone distance: ${minDistance.toInt()}m",
                        "timestamp" to Timestamp.now()
                    )
                    Firebase.firestore.collection("alerts").add(alert)
                    
                    showChildBoundaryNotification()
                }
            }
            .addOnFailureListener { e -> Log.e(TAG, "Failed to fetch safe zones: ${e.message}") }
    }

    private fun showChildBoundaryNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "BoundaryAlertChannel"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Safe Zone Alerts", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }
        
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Safe Zone Alert")
            .setContentText("You are outside the safe zone!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify(101, notification)
    }

    private fun launchMainActivity(type: String, message: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger", "DANGER")
            putExtra("alertType", type)
            putExtra("alertMessage", message)
        }
        startActivity(intent)
        Log.d(TAG, "Directly launched MainActivity due to emergency")
    }

    @Suppress("DEPRECATION")
    private fun showHighPriorityNotification(type: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val highChannelId = "EmergencyAlertChannel"

        // Violently wake up the screen
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            val wakeLock = powerManager.newWakeLock(
                android.os.PowerManager.FULL_WAKE_LOCK or
                android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP or
                android.os.PowerManager.ON_AFTER_RELEASE,
                "ChildGuard::EmergencyWakeLock"
            )
            wakeLock.acquire(10000) // Keep screen on for 10 seconds
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wakelock: ${e.message}")
        }

        // Native Vibration pattern (SOS: 3 short, 3 long, 3 short)
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(android.os.VibrationEffect.createWaveform(longArrayOf(0, 200, 200, 200, 200, 200, 500, 600, 500, 600, 500, 600), 0))
        } else {
            vibrator.vibrate(longArrayOf(0, 200, 200, 200, 200, 200, 500, 600, 500, 600, 500, 600), 0)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(highChannelId, "🚨 EMERGENCY ALERTS", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Critical alerts that wake up the app"
            channel.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
            channel.enableVibration(true)
            channel.vibrationPattern = longArrayOf(0, 500, 200, 500)
            channel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            channel.setBypassDnd(true) // Bypass Do Not Disturb
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger", "DANGER")
            putExtra("alertType", type)
            putExtra("alertMessage", message)
        }

        val pendingIntent = android.app.PendingIntent.getActivity(
            this, 0, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, highChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(if (type == "panic") "🚨 PANIC ALERT" else "⚠️ BOUNDARY ALERT")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pendingIntent, true)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setAutoCancel(true)
            .setOngoing(true) // Make it harder to dismiss
            .build()

        notificationManager.notify(100, notification)
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
        alertListenerRegistration?.remove()
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
        }
        super.onDestroy()
    }
}
