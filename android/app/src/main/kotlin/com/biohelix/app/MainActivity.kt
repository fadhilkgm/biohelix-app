package com.biohelix.app

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val INSTALL_REFERRER_CHANNEL = "com.biohelix.app/install_referrer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
