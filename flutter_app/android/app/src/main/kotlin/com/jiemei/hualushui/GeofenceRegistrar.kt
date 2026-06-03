package com.jiemei.hualushui

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.LocationServices

object GeofenceRegistrar {
    private const val PREFS = "attendance_geofence_config"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_LAT = "lat"
    private const val KEY_LNG = "lng"
    private const val KEY_RADIUS = "radius"

    fun unregister(context: Context): Result<String> {
        val client: GeofencingClient = LocationServices.getGeofencingClient(context)
        return try {
            client.removeGeofences(pendingIntent(context))
            saveConfig(context, enabled = false, latitude = null, longitude = null, radiusMeters = null)
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "unregister")
            Result.success("UNREGISTER_REQUEST_SUBMITTED")
        } catch (t: Throwable) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "unregister failed ${t.message}")
            Result.failure(t)
        }
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
