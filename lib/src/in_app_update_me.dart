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

  // A getter, not a `final` field: InAppUpdateMe is a permanent singleton, so
  // capturing InAppUpdateMePlatform.instance once at first construction would
  // permanently ignore any later `InAppUpdateMePlatform.instance = ...` —
  // e.g. the standard test-mocking pattern, or the singleton simply being
  // constructed before mocking is set up.
  InAppUpdateMePlatform get _platform => InAppUpdateMePlatform.instance;
  DefaultUpdateListener? _updateListener;
  DateTime? _lastAutoCheckAt;

  /// Initialize the plugin with configuration
  ///
  /// If [UpdateConfig.autoCheckOnAppStart] is true (the default), this kicks
  /// off a [performUpdateCheck] immediately, throttled to at most once per
  /// [UpdateConfig.checkInterval] for the lifetime of the app process. The
  /// result is delivered through the registered listener's
  /// `onUpdateCheckCompleted`/`onUpdateNotAvailable` callbacks, not a return
  /// value, since this method is synchronous.
  void initialize(UpdateConfig config) {
    // Don't clobber a listener the developer already registered.
    _updateListener ??= DefaultUpdateListener();
    _platform.setUpdateListener(_updateListener!);

    if (config.autoCheckOnAppStart) {
      final lastCheck = _lastAutoCheckAt;
      final dueForCheck =
          lastCheck == null || DateTime.now().difference(lastCheck) >= config.checkInterval;
      if (dueForCheck) {
        _lastAutoCheckAt = DateTime.now();
        // Fire-and-forget: checkForUpdate/performUpdateCheck already catch
        // their own errors and report them via the registered listener.
        performUpdateCheck(config);
      }
    }
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
  /// [headers]: Optional HTTP headers sent with the direct-update version check
  /// [timeout]: Optional timeout for the direct-update version check request
  Future<AppUpdateInfo?> checkForUpdate({
    bool useStore = true,
    String? updateUrl,
    String? currentVersion,
    Map<String, String>? headers,
    Duration? timeout,
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
        headers: headers,
        timeout: timeout,
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

  /// Start a flexible update
  /// For Android: Uses Google Play In-App Updates
  /// For iOS: Downloads update in background (for enterprise/ad-hoc apps)
  /// [downloadUrl]: Required for iOS direct updates, optional for Android
  Future<bool> startFlexibleUpdate({String? downloadUrl}) async {
    try {
      return await _platform.startFlexibleUpdate(downloadUrl: downloadUrl);
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
      if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        final storeUrl =
            'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';
        final uri = Uri.parse(storeUrl);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      } else if (Platform.isIOS) {
        // The App Store id is not known on the Dart side. Delegate to the
        // native layer, which resolves the correct App Store URL via the
        // iTunes lookup and opens it.
        return await _platform.startImmediateUpdate();
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening store: $e');
      }
      return false;
    }
  }

  /// The currently registered listener, if any. Exposed so UI built on top
  /// of this plugin (e.g. [ForceUpdateDialog]) can restore the caller's
  /// listener after temporarily replacing it with its own.
  DefaultUpdateListener? get currentListener => _updateListener;

  /// Set update listener for callbacks
  void setUpdateListener(DefaultUpdateListener listener) {
    _updateListener = listener;
    _platform.setUpdateListener(listener);
  }

  /// Remove update listener
  void removeUpdateListener() {
    _updateListener = null;
    _platform.removeUpdateListener();
  }

  /// Convenience method to perform a complete update check and handle force updates
  Future<UpdateResult> performUpdateCheck(UpdateConfig config) async {
    // DirectUpdateConfig builds its version-check URL from serverUrl +
    // versionEndpoint rather than setting the inherited updateUrl directly.
    final effectiveUpdateUrl =
        config is DirectUpdateConfig ? config.versionCheckUrl : config.updateUrl;

    final updateInfo = await checkForUpdate(
      useStore: config.useStore,
      updateUrl: effectiveUpdateUrl,
      headers: config is DirectUpdateConfig ? config.headers : null,
      timeout: config is DirectUpdateConfig ? config.timeout : null,
    );

    _updateListener?.onUpdateCheckCompleted(updateInfo?.updateAvailable ?? false);

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

    // Below the configured priority floor: still reported as available so
    // callers can show an optional prompt, but never auto-forced.
    final meetsMinimumPriority =
        (updateInfo.updatePriority ?? 0) >= config.minimumPriority.value;

    // Handle force update
    if (config.forceUpdate && meetsMinimumPriority) {
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