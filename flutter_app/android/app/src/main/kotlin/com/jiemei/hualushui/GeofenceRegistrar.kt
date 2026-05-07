package com.jiemei.hualushui

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

object GeofenceRegistrar {
    private const val GEOFENCE_ID = "jiemei_attendance_geofence"
    private const val PREFS = "attendance_geofence_config"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_LAT = "lat"
    private const val KEY_LNG = "lng"
    private const val KEY_RADIUS = "radius"

    fun register(context: Context, latitude: Double, longitude: Double, radiusMeters: Float): Result<String> {
        if (!hasLocationPermission(context)) {
            return Result.failure(IllegalStateException("LOCATION_PERMISSION_MISSING"))
        }
        val client: GeofencingClient = LocationServices.getGeofencingClient(context)
        val geofence = Geofence.Builder()
            .setRequestId(GEOFENCE_ID)
            .setCircularRegion(latitude, longitude, radiusMeters)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        return try {
            client.removeGeofences(pendingIntent(context))
            client.addGeofences(request, pendingIntent(context))
            AttendanceCommuteScheduler.cancel(context)
            saveConfig(context, enabled = true, latitude = latitude, longitude = longitude, radiusMeters = radiusMeters)
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "register lat=$latitude lng=$longitude radius=$radiusMeters")
            Result.success("REGISTER_REQUEST_SUBMITTED")
        } catch (t: Throwable) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "register failed ${t.message}")
            Result.failure(t)
        }
    }

    fun unregister(context: Context): Result<String> {
        val client: GeofencingClient = LocationServices.getGeofencingClient(context)
        return try {
            client.removeGeofences(pendingIntent(context))
            saveConfig(context, enabled = false, latitude = null, longitude = null, radiusMeters = null)
            AttendanceCommuteScheduler.cancel(context)
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "unregister")
            Result.success("UNREGISTER_REQUEST_SUBMITTED")
        } catch (t: Throwable) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "unregister failed ${t.message}")
            Result.failure(t)
        }
    }

    fun restoreIfNeeded(context: Context): Result<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_ENABLED, false)
        if (!enabled) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "restore skipped disabled")
            return Result.success("RESTORE_SKIPPED_DISABLED")
        }
        if (!hasLocationPermission(context)) {
            return Result.failure(IllegalStateException("LOCATION_PERMISSION_MISSING"))
        }
        val latBits = prefs.getLong(KEY_LAT, Long.MIN_VALUE)
        val lngBits = prefs.getLong(KEY_LNG, Long.MIN_VALUE)
        val radiusBits = prefs.getInt(KEY_RADIUS, -1)
        if (latBits == Long.MIN_VALUE || lngBits == Long.MIN_VALUE || radiusBits <= 0) {
            return Result.failure(IllegalStateException("CONFIG_MISSING"))
        }
        val latitude = java.lang.Double.longBitsToDouble(latBits)
        val longitude = java.lang.Double.longBitsToDouble(lngBits)
        AttendanceCommuteScheduler.cancel(context)
        AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "restore lat=$latitude lng=$longitude radius=$radiusBits")
        return register(context, latitude, longitude, radiusBits.toFloat())
    }

    fun config(context: Context): GeofenceConfig? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return null
        val latBits = prefs.getLong(KEY_LAT, Long.MIN_VALUE)
        val lngBits = prefs.getLong(KEY_LNG, Long.MIN_VALUE)
        val radius = prefs.getInt(KEY_RADIUS, -1)
        if (latBits == Long.MIN_VALUE || lngBits == Long.MIN_VALUE || radius <= 0) return null
        return GeofenceConfig(
            latitude = java.lang.Double.longBitsToDouble(latBits),
            longitude = java.lang.Double.longBitsToDouble(lngBits),
            radiusMeters = radius.toFloat(),
        )
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AttendanceGeofenceReceiver::class.java)
        intent.action = AttendanceGeofenceReceiver.ACTION_GEOFENCE_EVENT
        return PendingIntent.getBroadcast(
            context,
            99001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun hasLocationPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun saveConfig(
        context: Context,
        enabled: Boolean,
        latitude: Double?,
        longitude: Double?,
        radiusMeters: Float?,
    ) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit().putBoolean(KEY_ENABLED, enabled)
        if (!enabled || latitude == null || longitude == null || radiusMeters == null) {
            editor.remove(KEY_LAT).remove(KEY_LNG).remove(KEY_RADIUS).apply()
            return
        }
        editor
            .putLong(KEY_LAT, java.lang.Double.doubleToRawLongBits(latitude))
            .putLong(KEY_LNG, java.lang.Double.doubleToRawLongBits(longitude))
            .putInt(KEY_RADIUS, radiusMeters.toInt())
            .apply()
    }
}

data class GeofenceConfig(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float,
)
