package com.example.pilinara

import android.app.PictureInPictureParams
import android.app.SearchManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager.LayoutParams
import androidx.core.net.toUri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity : AudioServiceActivity() {
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "PiliNara")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "back" -> back();
                "biliSendCommAntifraud" -> {
                    try {
                        val action = call.argument<Int>("action") ?: 0
                        val oid = call.argument<Number>("oid") ?: 0L
                        val type = call.argument<Int>("type") ?: 0
                        val rpid = call.argument<Number>("rpid") ?: 0L
                        val root = call.argument<Number>("root") ?: 0L
                        val parent = call.argument<Number>("parent") ?: 0L
                        val ctime = call.argument<Number>("ctime") ?: 0L
                        val commentText = call.argument<String>("comment_text") ?: ""
                        val pictures = call.argument<String?>("pictures")
                        val sourceId = call.argument<String>("source_id") ?: ""
                        val uid = call.argument<Number>("uid") ?: 0L
                        val cookies = call.argument<List<String>>("cookies") ?: emptyList<String>()

                        val intent = Intent().apply {
                            component = ComponentName(
                                "icu.freedomIntrovert.biliSendCommAntifraud",
                                "icu.freedomIntrovert.biliSendCommAntifraud.ByXposedLaunchedActivity"
                            )
                            putExtra("action", action)
                            putExtra("oid", oid.toLong())
                            putExtra("type", type)
                            putExtra("rpid", rpid.toLong())
                            putExtra("root", root.toLong())
                            putExtra("parent", parent.toLong())
                            putExtra("ctime", ctime.toLong())
                            putExtra("comment_text", commentText)
                            if (pictures != null)
                                putExtra("pictures", pictures)
                            putExtra("source_id", sourceId)
                            putExtra("uid", uid.toLong())
                            putStringArrayListExtra("cookies", ArrayList(cookies))
                        }
                        startActivity(intent)
                    } catch (_: Exception) {
                    }
                }

                "linkVerifySettings" -> {
                    val uri = ("package:" + context.packageName).toUri()
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS, uri)
                        } else {
                            Intent("android.intent.action.MAIN", uri).setClassName(
                                "com.android.settings",
                                "com.android.settings.applications.InstalledAppOpenByDefaultActivity"
                            )
                        }
                        context.startActivity(intent)
                    } catch (_: Throwable) {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
                        context.startActivity(intent)
                    }
                }

                "music" -> {
                    val title = call.argument<String>("title")
                    val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_SEARCH).apply {
                        putExtra(SearchManager.QUERY, title)
                        putExtra(MediaStore.EXTRA_MEDIA_TITLE, title)
                        call.argument<String?>("artist")
                            ?.let { putExtra(MediaStore.EXTRA_MEDIA_ARTIST, it) }
                        call.argument<String?>("album")
                            ?.let { putExtra(MediaStore.EXTRA_MEDIA_ALBUM, it) }

                        addCategory(Intent.CATEGORY_DEFAULT)
                    }
                    try {
                        if (packageManager.resolveActivity(
                                intent,
                                PackageManager.MATCH_DEFAULT_ONLY
                            ) != null
                        ) {
                            startActivity(intent)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    } catch (_: Throwable) {
                    }
                    try {
                        intent.action = MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH
                        if (packageManager.resolveActivity(
                                intent,
                                PackageManager.MATCH_DEFAULT_ONLY
                            ) != null
                        ) {
                            startActivity(intent)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    } catch (_: Throwable) {
                    }
                    result.success(false)
                }

                "setPipAutoEnterEnabled" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val params = PictureInPictureParams.Builder()
                            .setAutoEnterEnabled(call.argument<Boolean>("autoEnable") ?: false)
                            .build()
                        setPictureInPictureParams(params)
                    }
                }

                "setFullScreenSourceRectHint" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val rect = call.argument<List<Int>>("sourceRectHint")
                        if (rect != null && rect.size == 4) {
                            val params = PictureInPictureParams.Builder()
                                .setSourceRectHint(android.graphics.Rect(rect[0], rect[1], rect[2], rect[3]))
                                .build()
                            setPictureInPictureParams(params)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // 向 Flutter 报告窗口焦点变化，用于过滤非切出场景的 inactive 状态
        methodChannel.invokeMethod("onWindowFocusChanged", hasFocus)
    }

    private fun back() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onDestroy() {
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        super.onDestroy()
        android.os.Process.killProcess(android.os.Process.myPid())
        exitProcess(0)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        methodChannel.invokeMethod("onUserLeaveHint", null)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel.invokeMethod("onPipChanged", isInPictureInPictureMode)
        MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            "floating"
        ).invokeMethod("onPipChanged", isInPictureInPictureMode)
    }
}
