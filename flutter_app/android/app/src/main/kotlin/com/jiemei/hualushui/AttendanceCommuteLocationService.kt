package com.jiemei.hualushui

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class AttendanceCommuteLocationService : Service() {
    private lateinit var client: FusedLocationProviderClient
    private var callback: LocationCallback? = null
    private var firstLocation: Location? = null
    private var highAccuracy = false

    override fun onCreate() {
        super.onCreate()
        client = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(2026050601, AttendanceNotifier.commuteForegroundNotification(this))
        val config = GeofenceRegistrar.config(this)
        if (config == null || !hasLocationPermission()) {
            AttendanceNativeLog.add(this, "COMMUTE_GPS", "stop no config/permission")
            stopSelf()
            return START_NOT_STICKY
        }
        if (!isMorningWindow()) {
            AttendanceNativeLog.add(this, "COMMUTE_GPS", "stop outside morning window")
            stopSelf()
            return START_NOT_STICKY
        }
        AttendanceNativeLog.add(this, "COMMUTE_GPS", "service start")
        requestUpdates(config, high = false)
        return START_STICKY
    }

    override fun onDestroy() {
        callback?.let { client.removeLocationUpdates(it) }
        AttendanceNativeLog.add(this, "COMMUTE_GPS", "service stop")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun requestUpdates(config: GeofenceConfig, high: Boolean) {
        callback?.let { client.removeLocationUpdates(it) }
        highAccuracy = high
        val interval = if (high) 15_000L else 60_000L
        val priority = if (high) Priority.PRIORITY_HIGH_ACCURACY else Priority.PRIORITY_BALANCED_POWER_ACCURACY
        val request = LocationRequest.Builder(priority, interval)
            .setMinUpdateIntervalMillis(if (high) 8_000L else 30_000L)
            .build()
        callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                handleLocation(config, location)
            }
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            AttendanceNativeLog.add(this, "COMMUTE_GPS", "request skipped permission missing")
            stopSelf()
            return
        }
        client.requestLocationUpdates(request, callback!!, Looper.getMainLooper())
    }

    private fun handleLocation(config: GeofenceConfig, location: Location) {
        if (!isMorningWindow()) {
            AttendanceNativeLog.add(this, "COMMUTE_GPS", "morning window ended")
            stopSelf()
            return
        }
        val target = Location("office").apply {
            latitude = config.latitude
            longitude = config.longitude
        }
        val distance = location.distanceTo(target)
        AttendanceNativeLog.add(
            this,
            "COMMUTE_GPS",
            "location lat=${location.latitude} lng=${location.longitude} acc=${location.accuracy} distance=${distance.toInt()} high=$highAccuracy",
        )
        if (distance <= config.radiusMeters) {
            markTriggeredToday()
            AttendanceNotifier.showCheckinReminder(this, "commute_gps")
            stopSelf()
            return
        }
        val first = firstLocation
        if (first == null) {
            firstLocation = location
            return
        }
        val moved = location.distanceTo(first)
        if (!highAccuracy && moved >= 80f) {
            AttendanceNativeLog.add(this, "COMMUTE_GPS", "movement=${moved.toInt()} switch high accuracy")
            requestUpdates(config, high = true)
        }
    }

    private fun markTriggeredToday() {
        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        getSharedPreferences("attendance_geofence", Context.MODE_PRIVATE)
            .edit()
            .putString("last_enter_day", todayKey)
            .apply()
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun isMorningWindow(): Boolean {
        val now = Calendar.getInstance()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 7)
            set(Calendar.MINUTE, 10)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val end = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 30)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return !now.before(start) && !now.after(end)
    }
}

