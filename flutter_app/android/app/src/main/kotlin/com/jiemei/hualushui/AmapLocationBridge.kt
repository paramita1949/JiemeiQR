package com.jiemei.hualushui

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.location.AMapLocationListener
import io.flutter.plugin.common.MethodChannel

object AmapLocationBridge {
    private const val API_KEY = "be92b9a884b84bd74a68b2ffbb6d5f44"

    fun locateOnce(context: Context, result: MethodChannel.Result) {
        val appContext = context.applicationContext
        AttendanceNativeLog.add(appContext, "AMAP_LOCATE", "start")
        try {
            AMapLocationClient.updatePrivacyShow(appContext, true, true)
            AMapLocationClient.updatePrivacyAgree(appContext, true)
            AMapLocationClient.setApiKey(API_KEY)
        } catch (t: Throwable) {
            AttendanceNativeLog.add(appContext, "AMAP_LOCATE", "privacy/apiKey failed ${t.message}")
        }

        val client = try {
            AMapLocationClient(appContext)
        } catch (t: Throwable) {
            AttendanceNativeLog.add(appContext, "AMAP_LOCATE", "client failed ${t.message}")
            result.error("AMAP_CLIENT_FAILED", t.message, null)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var completed = false
        fun finishSuccess(location: AMapLocation) {
            if (completed) return
            completed = true
            handler.removeCallbacksAndMessages(client)
            runCatching {
                client.stopLocation()
                client.onDestroy()
            }
            AttendanceNativeLog.add(
                appContext,
                "AMAP_LOCATE",
                "success lat=${location.latitude} lng=${location.longitude} acc=${location.accuracy} type=${location.locationType}",
            )
            result.success(
                mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                    "address" to (location.address ?: ""),
                    "locationType" to location.locationType,
                    "time" to location.time,
                    "provider" to "amap",
                ),
            )
        }

        fun finishError(code: String, message: String?) {
            if (completed) return
            completed = true
            handler.removeCallbacksAndMessages(client)
            runCatching {
                client.stopLocation()
                client.onDestroy()
            }
            AttendanceNativeLog.add(appContext, "AMAP_LOCATE", "$code $message")
            result.error(code, message, null)
        }

        val listener = AMapLocationListener { location ->
            if (location == null) {
                finishError("AMAP_LOCATION_NULL", "location is null")
                return@AMapLocationListener
            }
            if (location.errorCode == 0) {
                finishSuccess(location)
            } else {
                finishError(
                    "AMAP_LOCATION_FAILED",
                    "errCode=${location.errorCode}, errInfo=${location.errorInfo}",
                )
            }
        }

        client.setLocationListener(listener)
        val option = AMapLocationClientOption().apply {
            locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
            isOnceLocation = true
            isOnceLocationLatest = true
            isNeedAddress = true
            isLocationCacheEnable = true
            httpTimeOut = 8000
        }
        client.setLocationOption(option)
        handler.postDelayed(
            { finishError("AMAP_LOCATION_TIMEOUT", "高德定位超时") },
            client,
            9000,
        )
        try {
            client.startLocation()
        } catch (t: Throwable) {
            finishError("AMAP_START_FAILED", t.message)
        }
    }
}
