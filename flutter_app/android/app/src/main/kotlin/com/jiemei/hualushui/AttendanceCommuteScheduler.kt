package com.jiemei.hualushui

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

object AttendanceCommuteScheduler {
    private const val REQUEST_CODE = 99002

    fun schedule(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context)
        val trigger = nextSevenTen()
        manager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            trigger.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending,
        )
        AttendanceNativeLog.add(context, "COMMUTE_GPS", "scheduled 07:10")
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context))
        AttendanceNativeLog.add(context, "COMMUTE_GPS", "schedule canceled")
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AttendanceCommuteAlarmReceiver::class.java)
        intent.action = AttendanceCommuteAlarmReceiver.ACTION_START_COMMUTE_TRACKING
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextSevenTen(): Calendar {
        val now = Calendar.getInstance()
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 7)
            set(Calendar.MINUTE, 10)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
    }
}

