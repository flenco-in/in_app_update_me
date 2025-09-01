import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../in_app_update_me_platform_interface.dart';
import 'models/update_info.dart';
import 'models/update_config.dart';
import 'listeners/update_listener.dart';

class InAppUpdateMe {
  static final InAppUpdateMe _instance = InAppUpdateMe._internal();
  factory InAppUpdateMe() => _instance;
  InAppUpdateMe._internal();

  final InAppUpdateMePlatform _platform = InAppUpdateMePlatform.instance;
  DefaultUpdateListener? _updateListener;

  /// Initialize the plugin with configuration
  void initialize(UpdateConfig config) {
    _updateListener = DefaultUpdateListener();
    _platform.setUpdateListener(_updateListener!);
  }

  /// Get platform version for debugging
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Check for available updates
  /// 
  /// [useStore]: Whether to check Play Store/App Store (default: true)
  /// [updateUrl]: URL to check for direct updates (required if useStore is false)
  /// [currentVersion]: Current app version (optional, auto-detected if not provided)
  Future<AppUpdateInfo?> checkForUpdate({
    bool useStore = true,
    String? updateUrl,
    String? currentVersion,
  }) async {
    try {
      // Auto-detect current version if not provided
      if (currentVersion == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
      }

      final updateInfo = await _platform.checkForUpdate(
        useStore: useStore,
        updateUrl: updateUrl,
        currentVersion: currentVersion,
      );

      if (updateInfo != null) {
        return AppUpdateInfo.fromPlatformUpdateInfo(updateInfo);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for update: $e');
      }
      return null;
    }
  }

  /// Start a flexible update (Android only, iOS will redirect to App Store)
  Future<bool> startFlexibleUpdate() async {
    try {
      return await _platform.startFlexibleUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('Error starting flexible update: $e');
      }
      return false;
    }
  }

  /// Start an immediate update (Android only, iOS will redirect to App Store)
  Future<bool> startImmediateUpdate() async {
    try {
      return await _platform.startImmediateUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('Error starting immediate update: $e');
      }
      return false;
    }
  }

  /// Complete a flexible update (Android only)
  Future<bool> completeFlexibleUpdate() async {
    try {
      return await _platform.completeFlexibleUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('Error completing flexible update: $e');
      }
      return false;
    }
  }

  /// Download and install update directly
  /// For Android: Downloads and installs APK
  /// For iOS: Opens enterprise app URL or redirects to App Store
  Future<bool> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      return await _platform.downloadAndInstallUpdate(downloadUrl);
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading and installing update: $e');
      }
      return false;
    }
  }

  /// Check if an update is available (quick check)
  Future<bool> isUpdateAvailable() async {
    try {
      return await _platform.isUpdateAvailable();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking update availability: $e');
      }
      return false;
    }
  }

  /// Open App Store/Play Store for manual update
  Future<bool> openStore() async {
    try {
      String storeUrl;
      if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        storeUrl = 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';
      } else if (Platform.isIOS) {
        // This would need the actual App Store ID
        storeUrl = 'https://apps.apple.com/app/your-app-id';
      } else {
        return false;
      }

      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening store: $e');
      }
      return false;
    }
  }

  /// Set update listener for callbacks
  void setUpdateListener(DefaultUpdateListener listener) {
    _updateListener = listener;
    _platform.setUpdateListener(listener);
  }

  /// Remove update listener
  void removeUpdateListener() {
    _updateListener = null;
  }

  /// Convenience method to perform a complete update check and handle force updates
  Future<UpdateResult> performUpdateCheck(UpdateConfig config) async {
    final updateInfo = await checkForUpdate(
      useStore: config.useStore,
      updateUrl: config.updateUrl,
    );

    if (updateInfo == null) {
      return UpdateResult(
        updateAvailable: false,
        success: true,
        message: 'No update available',
      );
    }

    if (!updateInfo.updateAvailable) {
      return UpdateResult(
        updateAvailable: false,
        success: true,
        message: 'App is up to date',
      );
    }

    // Handle force update
    if (config.forceUpdate) {
      if (config.useStore) {
        if (Platform.isAndroid && updateInfo.immediateUpdateAllowed) {
          final success = await startImmediateUpdate();
          return UpdateResult(
            updateAvailable: true,
            success: success,
            message: success ? 'Force update initiated' : 'Failed to start force update',
            isForceUpdate: true,
          );
        } else {
          final success = await openStore();
          return UpdateResult(
            updateAvailable: true,
            success: success,
            message: success ? 'Redirected to store' : 'Failed to open store',
            isForceUpdate: true,
          );
        }
      } else if (updateInfo.downloadUrl != null) {
        final success = await downloadAndInstallUpdate(updateInfo.downloadUrl!);
        return UpdateResult(
          updateAvailable: true,
          success: success,
          message: success ? 'Direct update initiated' : 'Failed to download update',
          isForceUpdate: true,
        );
      }
    }

    return UpdateResult(
      updateAvailable: true,
      success: true,
      message: 'Update available',
      updateInfo: updateInfo,
    );
  }
}

class UpdateResult {
  final bool updateAvailable;
  final bool success;
  final String message;
  final AppUpdateInfo? updateInfo;
  final bool isForceUpdate;

  UpdateResult({
    required this.updateAvailable,
    required this.success,
    required this.message,
    this.updateInfo,
    this.isForceUpdate = false,
  });
}