package com.jiemei.hualushui

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object AttendanceNotifier {
    const val CHECKIN_CHANNEL_ID = "attendance_checkin_channel"
    const val COMMUTE_CHANNEL_ID = "attendance_commute_location_channel"

    fun showCheckinReminder(context: Context, source: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureCheckinChannel(manager)
        val notification = NotificationCompat.Builder(context, CHECKIN_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("签到提醒")
            .setContentText("已进入围栏范围，请完成签到")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()
        manager.notify(20260505, notification)
        AttendanceNativeLog.add(context, "GEOFENCE_POPUP", "show source=$source")
    }

    fun commuteForegroundNotification(context: Context): Notification {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureCommuteChannel(manager)
        return NotificationCompat.Builder(context, COMMUTE_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("上班围栏监测中")
            .setContentText("早上时段正在检测是否到达公司范围")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun ensureCheckinChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHECKIN_CHANNEL_ID,
            "考勤签到提醒",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "进入公司围栏后的签到提醒"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun ensureCommuteChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            COMMUTE_CHANNEL_ID,
            "上班围栏监测",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "早上上班时段的围栏定位监测"
        }
        manager.createNotificationChannel(channel)
    }
}

