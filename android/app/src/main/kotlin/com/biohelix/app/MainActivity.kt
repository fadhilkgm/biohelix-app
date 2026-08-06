package com.biohelix.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.ext.SdkExtensions
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL = "com.biohelix.app/fitness"
        const val INSTALL_REFERRER_CHANNEL = "com.biohelix.app/install_referrer"
        const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
    }

    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var permissionLauncher: ActivityResultLauncher<Set<String>>

    private val readPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        permissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted ->
            pendingPermissionResult?.success(
                mapOf(
                    "granted" to granted.containsAll(readPermissions),
                    "permissions" to granted.toList(),
                ),
            )
            pendingPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handleFitnessCall)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALL_REFERRER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallReferrer" -> getInstallReferrer(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstallReferrer(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(this).build()
        val delivered = AtomicBoolean(false)
        fun finish(value: String?) {
            if (delivered.compareAndSet(false, true)) {
                result.success(value)
            }
        }
        client.startConnection(
            object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                finish(client.installReferrer.installReferrer)
                            } catch (error: Exception) {
                                if (delivered.compareAndSet(false, true)) {
                                    result.error("install_referrer_read", error.message, null)
                                }
                            } finally {
                                client.endConnection()
                            }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                            client.endConnection()
                            finish(null)
                        }
                        InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
                            client.endConnection()
                            finish(null)
                        }
                        else -> {
                            client.endConnection()
                            finish(null)
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    finish(null)
                }
            },
        )
    }

    private fun handleFitnessCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> getStatus(result)
            "requestPermissions" -> requestPermissions(result)
            "readActivity" -> readActivity(call, result)
            "openHealthConnect" -> openHealthConnect(result)
            else -> result.notImplemented()
        }
    }

    private fun getStatus(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(statusPayload(HealthConnectClient.SDK_UNAVAILABLE, false))
            return
        }

        val sdkStatus = HealthConnectClient.getSdkStatus(this, HEALTH_CONNECT_PACKAGE)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(statusPayload(sdkStatus, false))
            return
        }

        activityScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity, HEALTH_CONNECT_PACKAGE)
                val granted = client.permissionController.getGrantedPermissions()
                result.success(statusPayload(sdkStatus, granted.containsAll(readPermissions)))
            } catch (error: Exception) {
                result.error("health_connect_status", error.message, null)
            }
        }
    }

    private fun statusPayload(sdkStatus: Int, granted: Boolean): Map<String, Any> {
        val status = when (sdkStatus) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "unavailable"
        }
        val nativePhoneSteps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            SdkExtensions.getExtensionVersion(Build.VERSION_CODES.UPSIDE_DOWN_CAKE) >= 20
        } else {
            false
        }
        return mapOf(
            "status" to status,
            "permissionsGranted" to granted,
            "nativePhoneStepTracking" to nativePhoneSteps,
            "androidVersion" to Build.VERSION.SDK_INT,
        )
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (HealthConnectClient.getSdkStatus(this, HEALTH_CONNECT_PACKAGE) !=
            HealthConnectClient.SDK_AVAILABLE
        ) {
            result.error("health_connect_unavailable", "Health Connect is unavailable.", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_active", "A permission request is already active.", null)
            return
        }
        pendingPermissionResult = result
        permissionLauncher.launch(readPermissions)
    }

    private fun readActivity(call: MethodCall, result: MethodChannel.Result) {
        val requestedDays = (call.argument<Int>("days") ?: 7).coerceIn(1, 7)
        if (HealthConnectClient.getSdkStatus(this, HEALTH_CONNECT_PACKAGE) !=
            HealthConnectClient.SDK_AVAILABLE
        ) {
            result.error("health_connect_unavailable", "Health Connect is unavailable.", null)
            return
        }

        activityScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity, HEALTH_CONNECT_PACKAGE)
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.containsAll(readPermissions)) {
                    result.error("health_connect_permission", "Health Connect permission is required.", null)
                    return@launch
                }

                val zone = ZoneId.systemDefault()
                val today = LocalDate.now(zone)
                val days = mutableListOf<Map<String, Any>>()
                for (offset in (requestedDays - 1) downTo 0) {
                    val date = today.minusDays(offset.toLong())
                    val start = date.atStartOfDay(zone).toInstant()
                    val end = date.plusDays(1).atStartOfDay(zone).toInstant()
                    val aggregate = client.aggregate(
                        AggregateRequest(
                            metrics = setOf(
                                StepsRecord.COUNT_TOTAL,
                                ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                                DistanceRecord.DISTANCE_TOTAL,
                            ),
                            timeRangeFilter = TimeRangeFilter.between(start, end),
                        ),
                    )
                    days.add(
                        mapOf(
                            "date" to date.toString(),
                            "steps" to (aggregate[StepsRecord.COUNT_TOTAL] ?: 0L),
                            "activeCalories" to (
                                aggregate[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]
                                    ?.inKilocalories ?: 0.0
                                ),
                            "distanceMeters" to (
                                aggregate[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0
                                ),
                        ),
                    )
                }

                result.success(
                    mapOf(
                        "timezone" to zone.id,
                        "days" to days,
                    ),
                )
            } catch (error: SecurityException) {
                result.error("health_connect_permission", error.message, null)
            } catch (error: Exception) {
                result.error("health_connect_read", error.message, null)
            }
        }
    }

    private fun openHealthConnect(result: MethodChannel.Result) {
        try {
            val sdkStatus = HealthConnectClient.getSdkStatus(this, HEALTH_CONNECT_PACKAGE)
            val intent: Intent =
                if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
                    Intent(Intent.ACTION_VIEW).apply {
                        setPackage("com.android.vending")
                        data = Uri.parse(
                            "market://details?id=$HEALTH_CONNECT_PACKAGE" +
                                "&url=healthconnect%3A%2F%2Fonboarding",
                        )
                        putExtra("overlay", true)
                        putExtra("callerId", packageName)
                    }
                } else {
                    HealthConnectClient.getHealthConnectManageDataIntent(
                        this,
                        HEALTH_CONNECT_PACKAGE,
                    )
                }
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("health_connect_open", error.message, null)
        }
    }

    override fun onDestroy() {
        activityScope.cancel()
        pendingPermissionResult = null
        super.onDestroy()
    }
}
