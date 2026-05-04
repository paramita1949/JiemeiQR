package com.jiemei.hualushui

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AttendanceGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_GEOFENCE_EVENT) return
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return

        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val prefs = context.getSharedPreferences("attendance_geofence", Context.MODE_PRIVATE)
        val lastDay = prefs.getString("last_enter_day", null)
        if (lastDay == todayKey) return

        showNotification(context)
        prefs.edit().putString("last_enter_day", todayKey).apply()
    }

    private fun showNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "attendance_checkin_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "考勤签到提醒",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "进入公司围栏后的签到提醒"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("签到提醒")
            .setContentText("已进入围栏范围，请完成签到")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()

        manager.notify(20260505, notification)
    }

    companion object {
        const val ACTION_GEOFENCE_EVENT = "com.jiemei.hualushui.ACTION_GEOFENCE_EVENT"
    }
}
