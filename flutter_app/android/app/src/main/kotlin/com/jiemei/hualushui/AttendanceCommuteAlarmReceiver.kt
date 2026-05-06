package com.jiemei.hualushui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AttendanceCommuteAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_START_COMMUTE_TRACKING) return
        val appContext = context.applicationContext
        if (GeofenceRegistrar.config(appContext) == null) {
            AttendanceNativeLog.add(appContext, "COMMUTE_GPS", "alarm skipped no config")
            return
        }
        AttendanceNativeLog.add(appContext, "COMMUTE_GPS", "alarm start service")
        val serviceIntent = Intent(appContext, AttendanceCommuteLocationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(serviceIntent)
        } else {
            appContext.startService(serviceIntent)
        }
    }

    companion object {
        const val ACTION_START_COMMUTE_TRACKING =
            "com.jiemei.hualushui.ACTION_START_COMMUTE_TRACKING"
    }
}

