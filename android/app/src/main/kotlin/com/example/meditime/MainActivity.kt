package com.example.meditime

import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SETTINGS_CHANNEL = "com.example.meditime/system_settings"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntentForAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkIntentForAlarm(intent)
    }

    private fun checkIntentForAlarm(intent: Intent?) {
        var isAlarm = false
        intent?.let {
            val payload = it.getStringExtra("payload")
            if (payload != null && payload.startsWith("alarm_mode")) {
                isAlarm = true
            }
        }
        
        if (isAlarm) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                window.addFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            } else {
                window.clearFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AlarmSoundPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "canScheduleExactAlarms" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(am.canScheduleExactAlarms())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "areNotificationsEnabled" -> {
                    try {
                        result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "getManufacturer" -> {
                    result.success(Build.MANUFACTURER ?: "Android")
                }
                "setLockScreenVisibility" -> {
                    val visible = call.argument<Boolean>("visible") ?: false
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                            setShowWhenLocked(visible)
                            setTurnScreenOn(visible)
                        } else {
                            if (visible) {
                                window.addFlags(
                                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                                )
                            } else {
                                window.clearFlags(
                                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                                )
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    val opened = openBatteryOptimization()
                    result.success(opened)
                }
                "openExactAlarmSettings" -> {
                    val opened = openExactAlarms()
                    result.success(opened)
                }
                "openNotificationSettings" -> {
                    val opened = openNotifications()
                    result.success(opened)
                }
                "openAppDetailsSettings" -> {
                    val opened = openAppDetails()
                    result.success(opened)
                }
                "canUseFullScreenIntent" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    val opened = openFullScreenIntent()
                    result.success(opened)
                }
                "openAutoStartSettings" -> {
                    val opened = openAutoStart()
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openBatteryOptimization(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return true
            }
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return true
            } catch (e2: Exception) {
                return openAppDetails()
            }
        }
        return openAppDetails()
    }

    private fun openExactAlarms(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return true
            }
        } catch (e: Exception) {
            return openAppDetails()
        }
        return openAppDetails()
    }

    private fun openNotifications(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return true
            }
        } catch (e: Exception) {
            return openAppDetails()
        }
        return openAppDetails()
    }

    private fun openFullScreenIntent(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return true
            }
        } catch (e: Exception) {
            return openAppDetails()
        }
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun openAutoStart(): Boolean {
        val intents = arrayOf(
            // Xiaomi / POCO / Redmi
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT),
            // Huawei / Honor
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")),
            // Samsung
            Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            // Oppo / Realme
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            // Vivo
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")),
            // Asus
            Intent().setComponent(ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity")),
            // Transsion (Tecno / Infinix)
            Intent().setComponent(ComponentName("com.transsion.phonemaster", "com.transsion.phonemaster.MainActivity"))
        )

        for (intent in intents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try next
            }
        }
        return openAppDetails()
    }
}

