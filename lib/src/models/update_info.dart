import '../../in_app_update_me_platform_interface.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final bool immediateUpdateAllowed;
  final bool flexibleUpdateAllowed;
  final int? availableVersionCode;
  final int? updatePriority;
  final String? appStoreVersion;
  final String? currentVersion;
  final String? appStoreUrl;
  final bool? directUpdate;
  final String? downloadUrl;

  AppUpdateInfo({
    required this.updateAvailable,
    this.immediateUpdateAllowed = false,
    this.flexibleUpdateAllowed = false,
    this.availableVersionCode,
    this.updatePriority,
    this.appStoreVersion,
    this.currentVersion,
    this.appStoreUrl,
    this.directUpdate,
    this.downloadUrl,
  });

  factory AppUpdateInfo.fromPlatformUpdateInfo(UpdateInfo platformInfo) {
    return AppUpdateInfo(
      updateAvailable: platformInfo.updateAvailable,
      immediateUpdateAllowed: platformInfo.immediateUpdateAllowed,
      flexibleUpdateAllowed: platformInfo.flexibleUpdateAllowed,
      availableVersionCode: platformInfo.availableVersionCode,
      updatePriority: platformInfo.updatePriority,
      appStoreVersion: platformInfo.appStoreVersion,
      currentVersion: platformInfo.currentVersion,
      appStoreUrl: platformInfo.appStoreUrl,
      directUpdate: platformInfo.directUpdate,
      downloadUrl: platformInfo.downloadUrl,
    );
  }

  /// Check if this is a high priority update
  bool get isHighPriority => updatePriority != null && updatePriority! >= 4;

  /// Check if this is a medium priority update
  bool get isMediumPriority => updatePriority != null && updatePriority! >= 2;

  /// Check if immediate update is recommended
  bool get shouldForceUpdate => isHighPriority && immediateUpdateAllowed;

  @override
  String toString() {
    return 'AppUpdateInfo('
        'updateAvailable: $updateAvailable, '
        'immediateUpdateAllowed: $immediateUpdateAllowed, '
        'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
        'availableVersionCode: $availableVersionCode, '
        'updatePriority: $updatePriority, '
        'appStoreVersion: $appStoreVersion, '
        'currentVersion: $currentVersion, '
        'directUpdate: $directUpdate, '
        'downloadUrl: $downloadUrl'
        ')';
  }
}