package com.focuscash.focus_cash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 집중 세션 중 "화면 꺼짐"과 "앱 이탈"을 구분하기 위한 채널.
 *
 * Flutter 라이프사이클은 두 경우 모두 AppLifecycleState.paused 로 동일하게 오기 때문에
 * Dart 만으로는 구분할 수 없다. 화면이 꺼져 있는 동안에는 다른 앱을 쓸 수 없으므로,
 * "일시정지 시점에 화면이 꺼져 있었는가" 한 가지만 알면 충분하다.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "focuscash/screen"

    /** 마지막 ACTION_SCREEN_OFF 수신 시각 (SystemClock.elapsedRealtime 기준) */
    private var lastScreenOffAt = 0L
    private var receiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                lastScreenOffAt = SystemClock.elapsedRealtime()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!receiverRegistered) {
            registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
            receiverRegistered = true
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isScreenOff" -> result.success(isScreenOff())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * onPause 와 디스플레이 상태 변경 사이에는 짧은 경쟁 구간이 있다.
     * isInteractive 가 아직 true 인 채로 onPause 가 먼저 도착할 수 있으므로,
     * 최근 2초 내 ACTION_SCREEN_OFF 수신 여부를 함께 본다.
     */
    private fun isScreenOff(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return true
        val since = SystemClock.elapsedRealtime() - lastScreenOffAt
        return lastScreenOffAt != 0L && since < 2_000L
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(screenReceiver)
            receiverRegistered = false
        }
        super.onDestroy()
    }
}
