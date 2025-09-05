package com.flenco.in_app_update_me

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import okhttp3.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class InAppUpdateMePlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private var appUpdateManager: AppUpdateManager? = null
  private val updateRequestCode = 100
  private var pendingResult: Result? = null
  
  private val installStateUpdatedListener = InstallStateUpdatedListener { state ->
    when (state.installStatus()) {
      InstallStatus.DOWNLOADED -> {
        channel.invokeMethod("onUpdateDownloaded", null)
      }
      InstallStatus.INSTALLED -> {
        channel.invokeMethod("onUpdateInstalled", null)
      }
      InstallStatus.FAILED -> {
        channel.invokeMethod("onUpdateFailed", mapOf("error" to "Installation failed"))
      }
      InstallStatus.DOWNLOADING -> {
        val progress = if (state.totalBytesToDownload() > 0) {
          (state.bytesDownloaded().toDouble() / state.totalBytesToDownload().toDouble() * 100).toInt()
        } else 0
        channel.invokeMethod("onUpdateProgress", mapOf("progress" to progress))
      }
    }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "in_app_update_me")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "checkForUpdate" -> checkForUpdate(call, result)
      "startFlexibleUpdate" -> startFlexibleUpdate(call, result)
      "startImmediateUpdate" -> startImmediateUpdate(call, result)
      "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
      "downloadAndInstallApk" -> downloadAndInstallApk(call, result)
      "isUpdateAvailable" -> isUpdateAvailable(result)
      "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
      else -> result.notImplemented()
    }
  }

  private fun checkForUpdate(call: MethodCall, result: Result) {
    val usePlayStore = call.argument<Boolean>("usePlayStore") ?: true
    
    if (usePlayStore) {
      checkPlayStoreUpdate(result)
    } else {
      val updateUrl = call.argument<String>("updateUrl")
      val currentVersion = call.argument<String>("currentVersion")
      if (updateUrl != null && currentVersion != null) {
        checkDirectUpdate(updateUrl, currentVersion, result)
      } else {
        result.error("INVALID_ARGUMENTS", "updateUrl and currentVersion are required for direct updates", null)
      }
    }
  }

  private fun checkPlayStoreUpdate(result: Result) {
    if (activity == null) {
      result.error("NO_ACTIVITY", "Activity is not available", null)
      return
    }

    if (appUpdateManager == null) {
      appUpdateManager = AppUpdateManagerFactory.create(context)
    }

    appUpdateManager?.appUpdateInfo?.addOnSuccessListener { appUpdateInfo ->
      val updateAvailable = appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
      val immediateAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
      val flexibleAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
      
      result.success(mapOf(
        "updateAvailable" to updateAvailable,
        "immediateUpdateAllowed" to immediateAllowed,
        "flexibleUpdateAllowed" to flexibleAllowed,
        "availableVersionCode" to appUpdateInfo.availableVersionCode(),
        "updatePriority" to appUpdateInfo.updatePriority()
      ))
    }?.addOnFailureListener { exception ->
      result.error("UPDATE_CHECK_FAILED", exception.message, null)
    }
  }

  private fun checkDirectUpdate(updateUrl: String, currentVersion: String, result: Result) {
    CoroutineScope(Dispatchers.IO).launch {
      try {
        val client = OkHttpClient()
        val request = Request.Builder().url(updateUrl).build()
        
        client.newCall(request).execute().use { response ->
          if (!response.isSuccessful) {
            withContext(Dispatchers.Main) {
              result.error("NETWORK_ERROR", "Failed to check for updates", null)
            }
            return@launch
          }

          val responseBody = response.body?.string()
          withContext(Dispatchers.Main) {
            result.success(mapOf(
              "updateAvailable" to true,
              "directUpdate" to true,
              "downloadUrl" to updateUrl,
              "currentVersion" to currentVersion
            ))
          }
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("UPDATE_CHECK_FAILED", e.message, null)
        }
      }
    }
  }

  private fun startFlexibleUpdate(call: MethodCall, result: Result) {
    if (activity == null || appUpdateManager == null) {
      result.error("NOT_AVAILABLE", "Activity or AppUpdateManager not available", null)
      return
    }

    appUpdateManager?.registerListener(installStateUpdatedListener)
    
    appUpdateManager?.appUpdateInfo?.addOnSuccessListener { appUpdateInfo ->
      if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
          appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
        
        try {
          appUpdateManager?.startUpdateFlowForResult(
            appUpdateInfo,
            activity!!,
            AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(),
            updateRequestCode
          )
          result.success(true)
        } catch (e: IntentSender.SendIntentException) {
          result.error("UPDATE_FAILED", e.message, null)
        }
      } else {
        result.error("UPDATE_NOT_AVAILABLE", "Flexible update not available", null)
      }
    }?.addOnFailureListener { exception ->
      result.error("UPDATE_FAILED", exception.message, null)
    }
  }

  private fun startImmediateUpdate(call: MethodCall, result: Result) {
    if (activity == null || appUpdateManager == null) {
      result.error("NOT_AVAILABLE", "Activity or AppUpdateManager not available", null)
      return
    }

    appUpdateManager?.appUpdateInfo?.addOnSuccessListener { appUpdateInfo ->
      if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
          appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
        
        try {
          appUpdateManager?.startUpdateFlowForResult(
            appUpdateInfo,
            activity!!,
            AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
            updateRequestCode
          )
          result.success(true)
        } catch (e: IntentSender.SendIntentException) {
          result.error("UPDATE_FAILED", e.message, null)
        }
      } else {
        result.error("UPDATE_NOT_AVAILABLE", "Immediate update not available", null)
      }
    }?.addOnFailureListener { exception ->
      result.error("UPDATE_FAILED", exception.message, null)
    }
  }

  private fun completeFlexibleUpdate(result: Result) {
    appUpdateManager?.completeUpdate()?.addOnSuccessListener {
      result.success(true)
    }?.addOnFailureListener { exception ->
      result.error("COMPLETE_UPDATE_FAILED", exception.message, null)
    }
  }

  private fun downloadAndInstallApk(call: MethodCall, result: Result) {
    val downloadUrl = call.argument<String>("downloadUrl")
    if (downloadUrl == null) {
      result.error("INVALID_ARGUMENTS", "downloadUrl is required", null)
      return
    }

    CoroutineScope(Dispatchers.IO).launch {
      try {
        val client = OkHttpClient()
        val request = Request.Builder().url(downloadUrl).build()
        
        client.newCall(request).execute().use { response ->
          if (!response.isSuccessful) {
            withContext(Dispatchers.Main) {
              result.error("DOWNLOAD_FAILED", "Failed to download APK", null)
            }
            return@launch
          }

          val file = File(context.getExternalFilesDir(null), "update.apk")
          val fos = FileOutputStream(file)
          
          response.body?.byteStream()?.use { inputStream ->
            val buffer = ByteArray(8192)
            var bytesRead: Int
            var totalBytesRead = 0L
            val totalSize = response.body?.contentLength() ?: 0L

            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
              fos.write(buffer, 0, bytesRead)
              totalBytesRead += bytesRead
              
              if (totalSize > 0) {
                val progress = (totalBytesRead.toDouble() / totalSize.toDouble() * 100).toInt()
                withContext(Dispatchers.Main) {
                  channel.invokeMethod("onUpdateProgress", mapOf("progress" to progress))
                }
              }
            }
          }
          
          fos.close()
          
          withContext(Dispatchers.Main) {
            installApk(file, result)
          }
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("DOWNLOAD_FAILED", e.message, null)
        }
      }
    }
  }

  private fun installApk(file: File, result: Result) {
    try {
      val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
      } else {
        Uri.fromFile(file)
      }

      val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
      }

      context.startActivity(intent)
      result.success(true)
    } catch (e: Exception) {
      result.error("INSTALL_FAILED", e.message, null)
    }
  }

  private fun isUpdateAvailable(result: Result) {
    if (appUpdateManager == null) {
      appUpdateManager = AppUpdateManagerFactory.create(context)
    }

    appUpdateManager?.appUpdateInfo?.addOnSuccessListener { appUpdateInfo ->
      val updateAvailable = appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
      result.success(updateAvailable)
    }?.addOnFailureListener { exception ->
      result.error("CHECK_FAILED", exception.message, null)
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode == updateRequestCode) {
      when (resultCode) {
        Activity.RESULT_OK -> {
          channel.invokeMethod("onUpdateResult", mapOf("result" to "success"))
        }
        Activity.RESULT_CANCELED -> {
          channel.invokeMethod("onUpdateResult", mapOf("result" to "cancelled"))
        }
        else -> {
          channel.invokeMethod("onUpdateResult", mapOf("result" to "failed"))
        }
      }
      return true
    }
    return false
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    appUpdateManager?.unregisterListener(installStateUpdatedListener)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}


