package com.example.faculty_sphere

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class AttendanceForegroundService : Service() {

    companion object {
        private const val TAG = "AttendanceService"
        private const val CHANNEL_ID = "background_location_channel"
        private const val NOTIFICATION_ID = 888

        // Control actions
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_UPDATE_GEOFENCE = "ACTION_UPDATE_GEOFENCE"

        // Keys for Intent extras
        const val EXTRA_BASE_URL = "EXTRA_BASE_URL"
        const val EXTRA_GEOFENCE_LAT = "EXTRA_GEOFENCE_LAT"
        const val EXTRA_GEOFENCE_LNG = "EXTRA_GEOFENCE_LNG"
        const val EXTRA_GEOFENCE_RADIUS = "EXTRA_GEOFENCE_RADIUS"
        const val EXTRA_TOKEN = "EXTRA_TOKEN"
        const val EXTRA_REG_NO = "EXTRA_REG_NO"
        const val EXTRA_DEVICE_SESSION_ID = "EXTRA_DEVICE_SESSION_ID"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var geofencingClient: GeofencingClient
    private var locationCallback: LocationCallback? = null
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)

    private var baseUrl: String = "https://attenda.srishakthicgpa.in"
    private var geofenceLat: Double = 11.0396
    private var geofenceLng: Double = 77.0747
    private var geofenceRadius: Float = 250f
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    private var token: String = ""
    private var regNo: String = ""
    private var deviceSessionId: String = ""
    private var startDay: String = ""

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        geofencingClient = LocationServices.getGeofencingClient(this)
        createNotificationChannel()

        // Acquire partial wake lock to keep service running when screen is off / phone is locked
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "AttendanceService::WakeLock").apply {
                acquire()
            }
            Log.d(TAG, "WakeLock acquired successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        Log.d(TAG, "Service started with action: $action")

        val prefs = getSharedPreferences("AttendanceNativePrefs", Context.MODE_PRIVATE)

        if (intent == null) {
            // Restore from SharedPreferences when restarted by system
            baseUrl = prefs.getString("baseUrl", baseUrl) ?: baseUrl
            geofenceLat = prefs.getFloat("geofenceLat", geofenceLat.toFloat()).toDouble()
            geofenceLng = prefs.getFloat("geofenceLng", geofenceLng.toFloat()).toDouble()
            geofenceRadius = prefs.getFloat("geofenceRadius", geofenceRadius)
            token = prefs.getString("token", "") ?: ""
            regNo = prefs.getString("regNo", "") ?: ""
            deviceSessionId = prefs.getString("deviceSessionId", "") ?: ""
            startDay = prefs.getString("startDay", "") ?: ""
            Log.d(TAG, "Restored service state: baseUrl=$baseUrl, geofenceLat=$geofenceLat, geofenceLng=$geofenceLng")
        } else {
            intent.getStringExtra(EXTRA_BASE_URL)?.let { baseUrl = it }
            if (intent.hasExtra(EXTRA_GEOFENCE_LAT)) {
                geofenceLat = intent.getDoubleExtra(EXTRA_GEOFENCE_LAT, geofenceLat)
                geofenceLng = intent.getDoubleExtra(EXTRA_GEOFENCE_LNG, geofenceLng)
                geofenceRadius = intent.getFloatExtra(EXTRA_GEOFENCE_RADIUS, geofenceRadius)
            }
            intent.getStringExtra(EXTRA_TOKEN)?.let { token = it }
            intent.getStringExtra(EXTRA_REG_NO)?.let { regNo = it }
            intent.getStringExtra(EXTRA_DEVICE_SESSION_ID)?.let { deviceSessionId = it }

            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            sdf.timeZone = TimeZone.getTimeZone("GMT+5:30")
            startDay = sdf.format(Date())

            // Save settings to SharedPreferences so that they persist on restart
            prefs.edit().apply {
                putString("baseUrl", baseUrl)
                putFloat("geofenceLat", geofenceLat.toFloat())
                putFloat("geofenceLng", geofenceLng.toFloat())
                putFloat("geofenceRadius", geofenceRadius)
                putString("token", token)
                putString("regNo", regNo)
                putString("deviceSessionId", deviceSessionId)
                putString("startDay", startDay)
                apply()
            }
        }

        when (action) {
            ACTION_START -> {
                startForegroundService()
                setupGeofence()
                startLocationUpdates()
            }
            ACTION_STOP -> {
                stopLocationUpdates()
                removeGeofence()
                stopForeground(true)
                stopSelf()
            }
            ACTION_UPDATE_GEOFENCE -> {
                setupGeofence()
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed (app swiped away). Restarting service using AlarmManager...")
        val restartServiceIntent = Intent(applicationContext, this.javaClass).apply {
            setPackage(packageName)
            action = ACTION_START
            putExtra(EXTRA_BASE_URL, baseUrl)
            putExtra(EXTRA_GEOFENCE_LAT, geofenceLat)
            putExtra(EXTRA_GEOFENCE_LNG, geofenceLng)
            putExtra(EXTRA_GEOFENCE_RADIUS, geofenceRadius)
        }
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext, 1, restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmService.set(
                AlarmManager.ELAPSED_REALTIME,
                android.os.SystemClock.elapsedRealtime() + 1000,
                restartServicePendingIntent
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set alarm for restart: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun startForegroundService() {
        val notification = createNotification("Attenda Location Sync", "Background tracking is active.")
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun updateNotification(title: String, content: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = createNotification(title, content)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotification(title: String, content: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(resources.getIdentifier("ic_launcher", "mipmap", packageName))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT or Notification.FLAG_NO_CLEAR
        return notification
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Attenda Location Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running in the background to verify location attendance."
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun shouldTrack(): Boolean {
        if (token.isEmpty() || regNo.isEmpty()) return false

        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        sdf.timeZone = TimeZone.getTimeZone("GMT+5:30")
        val today = sdf.format(Date())
        
        if (today != startDay) {
            Log.d(TAG, "Day changed (started on $startDay, today is $today). Auto-stopping tracking...")
            stopLocationUpdates()
            stopSelf()
            return false
        }
        return true
    }

    private fun startLocationUpdates() {
        if (locationCallback != null) return

        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 120000L).apply {
            setMinUpdateIntervalMillis(120000L)
            setWaitForAccurateLocation(true)
        }.build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    onLocationChanged(location)
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            Log.d(TAG, "Location updates requested successfully.")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permissions missing: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
            locationCallback = null
            Log.d(TAG, "Location updates stopped.")
        }
    }

    private fun setupGeofence() {
        val geofence = Geofence.Builder()
            .setRequestId("college_geofence")
            .setCircularRegion(geofenceLat, geofenceLng, geofenceRadius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        try {
            geofencingClient.addGeofences(request, pendingIntent).run {
                addOnSuccessListener {
                    Log.d(TAG, "Geofence added successfully at ($geofenceLat, $geofenceLng) r=$geofenceRadius")
                }
                addOnFailureListener { e ->
                    Log.e(TAG, "Failed to add geofence: ${e.message}")
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Permissions missing for geofence: ${e.message}")
        }
    }

    private fun removeGeofence() {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        geofencingClient.removeGeofences(pendingIntent).run {
            addOnSuccessListener { Log.d(TAG, "Geofences removed successfully") }
            addOnFailureListener { Log.e(TAG, "Failed to remove geofences") }
        }
    }

    private fun onLocationChanged(location: Location) {
        if (!shouldTrack()) {
            Log.d(TAG, "Not tracking: outside check-in/out window for today.")
            return
        }
        Log.d(TAG, "New Location: ${location.latitude}, ${location.longitude}")
        
        // Push update to backend in coroutine
        serviceScope.launch {
            sendLocationToBackend(location)
        }
    }

    private suspend fun sendLocationToBackend(location: Location) {
        try {
            if (token.isEmpty() || regNo.isEmpty()) return

            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
            sdf.timeZone = TimeZone.getTimeZone("GMT+5:30")
            val capturedAtIST = sdf.format(Date(location.time)) + "+05:30"

            val payload = JSONObject().apply {
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("accuracy_meters", location.accuracy)
                put("speed_mps", location.speed)
                put("heading_deg", location.bearing)
                put("altitude_m", location.altitude)
                put("is_mocked", location.isFromMockProvider)
                put("source", "native_background_service")
                put("app_state", "background")
                put("captured_at", capturedAtIST)
                put("device_id", if (deviceSessionId.isNotEmpty()) deviceSessionId else "app_$regNo")
            }

            val conn = URL("$baseUrl/location/update").openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.doOutput = true

            OutputStreamWriter(conn.outputStream).use { writer ->
                writer.write(payload.toString())
                writer.flush()
            }

            val responseCode = conn.responseCode
            Log.d(TAG, "Send location response code: $responseCode")
            
            if (responseCode in 200..299) {
                val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                val responseJson = JSONObject(responseStr)
                
                if (responseJson.optBoolean("boundary_warning", false)) {
                    val warning = responseJson.optString("warning", "")
                    updateNotification("⚠ Boundary Breach Detected!", warning)
                } else {
                    updateNotification("Attenda Location Sync", "Location synchronized successfully.")
                }
            }
            conn.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error sending location to backend: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
            Log.d(TAG, "WakeLock released.")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing WakeLock: ${e.message}")
        }
        serviceJob.cancel()
        Log.d(TAG, "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
