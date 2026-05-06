package com.jiemei.hualushui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AttendanceGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_GEOFENCE_EVENT) return
        AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "receiver invoked")
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "receiver error=${event.errorCode}")
            return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "transition=${event.geofenceTransition}")
            return
        }

        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val prefs = context.getSharedPreferences("attendance_geofence", Context.MODE_PRIVATE)
        val lastDay = prefs.getString("last_enter_day", null)
        if (lastDay == todayKey) {
            AttendanceNativeLog.add(context, "GEOFENCE_NATIVE", "skip already triggered today")
            return
        }

        AttendanceNotifier.showCheckinReminder(context, "native_geofence")
        prefs.edit().putString("last_enter_day", todayKey).apply()
    }

    companion object {
        const val ACTION_GEOFENCE_EVENT = "com.jiemei.hualushui.ACTION_GEOFENCE_EVENT"
    }
}
