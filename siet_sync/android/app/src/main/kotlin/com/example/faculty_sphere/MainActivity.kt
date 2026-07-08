package com.example.faculty_sphere

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "attendance"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val baseUrl = call.argument<String>("baseUrl") ?: "https://attenda.srishakthicgpa.in"
                    val lat = call.argument<Double>("geofenceLat") ?: 11.0396
                    val lng = call.argument<Double>("geofenceLng") ?: 77.0747
                    val radius = call.argument<Double>("geofenceRadius")?.toFloat() ?: 250f
                    val token = call.argument<String>("token") ?: ""
                    val regNo = call.argument<String>("regNo") ?: ""
                    val deviceSessionId = call.argument<String>("deviceSessionId") ?: ""

                    val serviceIntent = Intent(this, AttendanceForegroundService::class.java).apply {
                        action = AttendanceForegroundService.ACTION_START
                        putExtra(AttendanceForegroundService.EXTRA_BASE_URL, baseUrl)
                        putExtra(AttendanceForegroundService.EXTRA_GEOFENCE_LAT, lat)
                        putExtra(AttendanceForegroundService.EXTRA_GEOFENCE_LNG, lng)
                        putExtra(AttendanceForegroundService.EXTRA_GEOFENCE_RADIUS, radius)
                        putExtra(AttendanceForegroundService.EXTRA_TOKEN, token)
                        putExtra(AttendanceForegroundService.EXTRA_REG_NO, regNo)
                        putExtra(AttendanceForegroundService.EXTRA_DEVICE_SESSION_ID, deviceSessionId)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val serviceIntent = Intent(this, AttendanceForegroundService::class.java).apply {
                        action = AttendanceForegroundService.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
