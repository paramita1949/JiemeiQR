package com.jiemei.hualushui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AttendanceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val appContext = context.applicationContext
        val result = GeofenceRegistrar.restoreIfNeeded(appContext)
        AttendanceNativeLog.add(appContext, "GEOFENCE_NATIVE", "boot restore ${result.getOrNull() ?: result.exceptionOrNull()?.message}")
    }
}
