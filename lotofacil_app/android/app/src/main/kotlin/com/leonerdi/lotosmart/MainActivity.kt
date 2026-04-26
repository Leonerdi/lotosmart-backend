package com.leonerdi.lotosmart

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "lotosmart/pip"
	private val pipPreviousAction = "com.leonerdi.lotosmart.PIP_PREVIOUS"
	private val pipNextAction = "com.leonerdi.lotosmart.PIP_NEXT"
	private lateinit var methodChannel: MethodChannel
	private var receiverRegistered = false
	private var lastPipNumerator = 9
	private var lastPipDenominator = 16

	private val pipReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context?, intent: Intent?) {
			val method = when (intent?.action) {
				pipPreviousAction -> "pipPrevious"
				pipNextAction -> "pipNext"
				else -> null
			} ?: return

			runOnUiThread {
				methodChannel.invokeMethod(method, null)
			}
		}
	}

	override fun onStart() {
		super.onStart()
		registerPipReceiverIfNeeded()
	}

	override fun onDestroy() {
		unregisterPipReceiverIfNeeded()
		super.onDestroy()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

		methodChannel
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isPipSupported" -> {
						val supported =
							Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
								packageManager.hasSystemFeature("android.software.picture_in_picture")
						result.success(supported)
					}
					"enterPip" -> {
						if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
							result.success(false)
							return@setMethodCallHandler
						}

						val numerator = call.argument<Int>("numerator") ?: 9
						val denominator = call.argument<Int>("denominator") ?: 16
						lastPipNumerator = numerator
						lastPipDenominator = denominator

						val params = buildPipParams(
							numerator = lastPipNumerator,
							denominator = lastPipDenominator,
							actions = buildPipActions(canGoPrevious = true, canGoNext = true)
						)

						val entered = enterPictureInPictureMode(params)
						result.success(entered)
					}
					"setPipActions" -> {
						if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
							result.success(false)
							return@setMethodCallHandler
						}

						val canGoPrevious = call.argument<Boolean>("canGoPrevious") ?: false
						val canGoNext = call.argument<Boolean>("canGoNext") ?: false
						setPictureInPictureParams(
							buildPipParams(
								numerator = lastPipNumerator,
								denominator = lastPipDenominator,
								actions = buildPipActions(canGoPrevious, canGoNext)
							)
						)
						result.success(true)
					}
					"clearPipActions" -> {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							setPictureInPictureParams(
								buildPipParams(
									numerator = lastPipNumerator,
									denominator = lastPipDenominator,
									actions = emptyList()
								)
							)
						}
						result.success(true)
					}
					"openLoteriasAppOrBrowser" -> {
						val packageName = call.argument<String>("packageName")
						val url = call.argument<String>("url")
						result.success(openLoteriasAppOrBrowser(packageName, url))
					}
					"openPackage" -> {
						val packageName = call.argument<String>("packageName")
						result.success(openPackage(packageName))
					}
					"openUrl" -> {
						val url = call.argument<String>("url")
						result.success(openUrl(url))
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun registerPipReceiverIfNeeded() {
		if (receiverRegistered) return

		val filter = IntentFilter().apply {
			addAction(pipPreviousAction)
			addAction(pipNextAction)
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
		} else {
			registerReceiver(pipReceiver, filter)
		}
		receiverRegistered = true
	}

	private fun unregisterPipReceiverIfNeeded() {
		if (!receiverRegistered) return
		unregisterReceiver(pipReceiver)
		receiverRegistered = false
	}

	private fun buildPipParams(
		numerator: Int,
		denominator: Int,
		actions: List<RemoteAction>,
	): PictureInPictureParams {
		val safeNumerator = numerator.coerceAtLeast(1)
		val safeDenominator = denominator.coerceAtLeast(1)
		val builder = PictureInPictureParams.Builder()
			.setAspectRatio(Rational(safeNumerator, safeDenominator))
			.setActions(actions)

		// Ajuda o Android a manter bounds/oclusão corretos do PiP.
		val visibleRect = Rect()
		window.decorView.getGlobalVisibleRect(visibleRect)
		if (!visibleRect.isEmpty) {
			builder.setSourceRectHint(visibleRect)
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			builder.setSeamlessResizeEnabled(false)
		}

		return builder.build()
	}

	private fun buildPipActions(canGoPrevious: Boolean, canGoNext: Boolean): List<RemoteAction> {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()

		val actions = mutableListOf<RemoteAction>()
		if (canGoPrevious) {
			actions += RemoteAction(
				Icon.createWithResource(this, android.R.drawable.ic_media_previous),
				"Ver Sequência",
				"Ver sequência anterior",
				PendingIntent.getBroadcast(
					this,
					1,
					Intent(pipPreviousAction).setPackage(packageName),
					PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
				)
			)
		}
		if (canGoNext) {
			actions += RemoteAction(
				Icon.createWithResource(this, android.R.drawable.ic_media_next),
				"Próxima Sugestão",
				"Ir para próxima sugestão",
				PendingIntent.getBroadcast(
					this,
					2,
					Intent(pipNextAction).setPackage(packageName),
					PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
				)
			)
		}
		return actions
	}

	private fun openLoteriasAppOrBrowser(packageName: String?, url: String?): Boolean {
		val openedPackage = openPackage(packageName)
		if (openedPackage) return true
		return openUrl(url)
	}

	private fun openPackage(packageName: String?): Boolean {
		try {
			if (!packageName.isNullOrBlank()) {
				packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					startActivity(intent)
					return true
				}

				val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
					addCategory(Intent.CATEGORY_LAUNCHER)
					setPackage(packageName)
					addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				}
				val launchers = packageManager.queryIntentActivities(launcherIntent, 0)
				if (launchers.isNotEmpty()) {
					val activityName = launchers.first().activityInfo.name
					launcherIntent.setClassName(packageName, activityName)
					startActivity(launcherIntent)
					return true
				}

				val viewIntent = Intent(Intent.ACTION_VIEW).apply {
					setPackage(packageName)
					addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				}
				if (viewIntent.resolveActivity(packageManager) != null) {
					startActivity(viewIntent)
					return true
				}
			}
		} catch (_: Exception) {
		}

		return false
	}

	private fun openUrl(url: String?): Boolean {
		try {
			if (!url.isNullOrBlank()) {
				startActivity(
					Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
						addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					}
				)
				return true
			}
		} catch (_: Exception) {
		}

		return false
	}
}
