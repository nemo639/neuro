package com.example.neuroverse

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.neuroverse/usage_stats"

    // Common gaming package prefixes / known game packages
    private val gamingPackages = setOf(
        "com.supercell", "com.king", "com.ea.game", "com.gameloft",
        "com.epicgames", "com.activision", "com.tencent.ig",
        "com.pubg", "com.mojang", "com.roblox", "com.innersloth",
        "com.dts.freefireth", "com.mobile.legends", "com.kiloo",
        "com.imangi", "com.halfbrick", "com.rovio", "com.miniclip",
        "com.nekki", "com.outfit7", "com.voodoo", "com.ketchapp",
        "com.playgendary", "games", "game"
    )

    // Common social media packages
    private val socialPackages = setOf(
        "com.facebook.katana", "com.facebook.orca", "com.facebook.lite",
        "com.instagram.android", "com.twitter.android", "com.twitter.android.lite",
        "com.zhiliaoapp.musically", // TikTok
        "com.ss.android.ugc.trill", // TikTok (alt)
        "com.snapchat.android", "com.whatsapp", "com.whatsapp.w4b",
        "org.telegram.messenger", "com.discord",
        "com.linkedin.android", "com.pinterest", "com.reddit.frontpage",
        "com.tumblr", "us.zoom.videomeetings", "com.google.android.youtube",
        "com.viber.voip", "jp.naver.line.android", "com.skype.raider"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsageStats" -> {
                        if (!hasUsagePermission()) {
                            // Open usage access settings so user can grant permission
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null) // Return null → Flutter falls back
                        } else {
                            val stats = getUsageStats()
                            result.success(stats)
                        }
                    }
                    "hasUsagePermission" -> {
                        result.success(hasUsagePermission())
                    }
                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsageStats(): HashMap<String, Any> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Query today's usage from midnight to now
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        var totalScreenMinutes = 0L
        var gamingMinutes = 0L
        var socialMinutes = 0L

        if (stats != null) {
            for (stat in stats) {
                val pkg = stat.packageName ?: continue
                val minutes = stat.totalTimeInForeground / 1000 / 60

                if (minutes <= 0) continue

                totalScreenMinutes += minutes

                // Classify as gaming
                if (isGamingApp(pkg)) {
                    gamingMinutes += minutes
                }

                // Classify as social
                if (isSocialApp(pkg)) {
                    socialMinutes += minutes
                }
            }
        }

        // Get notification count from usage events
        var notificationCount = 0
        try {
            val events = usm.queryEvents(startTime, endTime)
            val event = android.app.usage.UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                // Event type 12 = NOTIFICATION_SEEN (hidden constant)
                if (event.eventType == 12) {
                    notificationCount++
                }
            }
        } catch (_: Exception) {
            // Some devices don't support event queries
        }

        val result = HashMap<String, Any>()
        result["screenTimeMinutes"] = totalScreenMinutes.toInt()
        result["gamingMinutes"] = gamingMinutes.toInt()
        result["socialMinutes"] = socialMinutes.toInt()
        result["notificationCount"] = notificationCount
        return result
    }

    private fun isGamingApp(packageName: String): Boolean {
        // Check exact matches and prefix matches
        for (prefix in gamingPackages) {
            if (packageName.startsWith(prefix) || packageName.contains(".game") || packageName.contains(".games")) {
                return true
            }
        }
        // Try to detect via app category (Android O+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                if (appInfo.category == android.content.pm.ApplicationInfo.CATEGORY_GAME) {
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }

    private fun isSocialApp(packageName: String): Boolean {
        return socialPackages.contains(packageName) ||
               packageName.contains("social") ||
               packageName.contains("messenger") ||
               packageName.contains("chat")
    }
}
