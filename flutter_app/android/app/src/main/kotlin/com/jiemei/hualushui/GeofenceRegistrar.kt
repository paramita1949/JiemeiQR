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
            Result.success("REGISTER_REQUEST_SUBMITTED")
        } catch (t: Throwable) {
            Result.failure(t)
        }
    }

    fun unregister(context: Context): Result<String> {
        val client: GeofencingClient = LocationServices.getGeofencingClient(context)
        return try {
            client.removeGeofences(pendingIntent(context))
            Result.success("UNREGISTER_REQUEST_SUBMITTED")
        } catch (t: Throwable) {
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

    private fun hasLocationPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }
}
