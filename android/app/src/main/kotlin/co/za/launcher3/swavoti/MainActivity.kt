package co.za.launcher3.swavoti

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val WIDGET_CHANNEL = "co.za.launcher3.swavoti/widgets"
    private val SYSTEM_CHANNEL = "co.za.launcher3.swavoti/system"
    private val NOTIFICATION_CHANNEL = "co.za.launcher3.swavoti/notifications"

    private lateinit var appWidgetManager: AppWidgetManager
    private lateinit var appWidgetHost: AppWidgetHost
    private val APPWIDGET_HOST_ID = 1024
    private val REQUEST_BIND_APPWIDGET = 100

    private var pendingWidgetIdToBind: Int = -1
    private var pendingWidgetMethodResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetManager = AppWidgetManager.getInstance(this)
        appWidgetHost = AppWidgetHost(this, APPWIDGET_HOST_ID)
        appWidgetHost.startListening()
    }

    override fun onDestroy() {
        super.onDestroy()
        appWidgetHost.stopListening()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "widget_view",
            WidgetViewFactory(appWidgetHost)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllWidgets" -> {
                    val providers = appWidgetManager.installedProviders
                    val widgetList = mutableListOf<Map<String, Any>>()

                    for (info in providers) {
                        val map = mutableMapOf<String, Any>()
                        map["providerPackage"] = info.provider.packageName
                        map["providerClass"] = info.provider.className
                        map["label"] = info.loadLabel(packageManager)
                        
                        val previewImage = info.loadPreviewImage(context, 0)
                        val iconImage = info.loadIcon(context, 0)
                        
                        val drawableToConvert = previewImage ?: iconImage
                        if (drawableToConvert != null) {
                            val bytes = drawableToByteArray(drawableToConvert)
                            map["preview"] = bytes
                        }
                        
                        widgetList.add(map)
                    }
                    result.success(widgetList)
                }
                "allocateWidgetId" -> {
                    val id = appWidgetHost.allocateAppWidgetId()
                    result.success(id)
                }
                "bindWidget" -> {
                    val appWidgetId = call.argument<Int>("appWidgetId") ?: -1
                    val providerPackage = call.argument<String>("providerPackage") ?: ""
                    val providerClass = call.argument<String>("providerClass") ?: ""

                    if (appWidgetId != -1 && providerPackage.isNotEmpty()) {
                        val provider = ComponentName(providerPackage, providerClass)
                        val success = appWidgetManager.bindAppWidgetIdIfAllowed(appWidgetId, provider)
                        if (success) {
                            result.success(true)
                        } else {
                            // Request permission
                            pendingWidgetIdToBind = appWidgetId
                            pendingWidgetMethodResult = result
                            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, provider)
                            startActivityForResult(intent, REQUEST_BIND_APPWIDGET)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }
                "deleteWidgetId" -> {
                    val appWidgetId = call.argument<Int>("appWidgetId") ?: -1
                    if (appWidgetId != -1) {
                        appWidgetHost.deleteAppWidgetId(appWidgetId)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val intent = Intent(Intent.ACTION_DELETE)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "appInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "changeWallpaper" -> {
                    val intent = Intent(Intent.ACTION_SET_WALLPAPER)
                    startActivity(Intent.createChooser(intent, "Select Wallpaper"))
                    result.success(null)
                }
                "openGoogleDiscover" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN)
                        intent.setClassName("com.google.android.googlequicksearchbox", "com.google.android.apps.gsa.staticplugins.opa.OpaActivity")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            val intent2 = Intent(Intent.ACTION_MAIN)
                            intent2.setPackage("com.google.android.googlequicksearchbox")
                            startActivity(intent2)
                        } catch (e2: Exception) {}
                    }
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        startActivity(intent)
                    } catch (e: Exception) {}
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationDotService.listener = { map ->
                        events?.success(map)
                    }
                    // Trigger initial
                    NotificationDotService.listener?.invoke(NotificationDotService.notificationCounts)
                }

                override fun onCancel(arguments: Any?) {
                    NotificationDotService.listener = null
                }
            }
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_BIND_APPWIDGET) {
            if (resultCode == Activity.RESULT_OK) {
                pendingWidgetMethodResult?.success(true)
            } else {
                if (pendingWidgetIdToBind != -1) {
                    appWidgetHost.deleteAppWidgetId(pendingWidgetIdToBind)
                }
                pendingWidgetMethodResult?.success(false)
            }
            pendingWidgetIdToBind = -1
            pendingWidgetMethodResult = null
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = Bitmap.createBitmap(
            Math.max(1, drawable.intrinsicWidth),
            Math.max(1, drawable.intrinsicHeight),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
