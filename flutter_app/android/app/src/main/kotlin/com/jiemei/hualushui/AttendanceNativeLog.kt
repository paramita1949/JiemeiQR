package com.jiemei.hualushui

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object AttendanceNativeLog {
    private const val PREFS = "attendance_native_logs"
    private const val KEY_LINES = "lines"
    private const val MAX_LINES = 120

    fun add(context: Context, tag: String, message: String) {
        val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault()).format(Date())
        val line = "$ts [$tag] $message"
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lines = prefs.getString(KEY_LINES, "")!!
            .lines()
            .filter { it.isNotBlank() }
            .toMutableList()
        lines.add(line)
        val trimmed = lines.takeLast(MAX_LINES)
        prefs.edit().putString(KEY_LINES, trimmed.joinToString("\n")).apply()
    }

    fun dump(context: Context): String {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_LINES, "") ?: ""
    }
}

