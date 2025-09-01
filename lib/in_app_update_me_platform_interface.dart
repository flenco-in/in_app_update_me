import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'in_app_update_me_method_channel.dart';

abstract class InAppUpdateMePlatform extends PlatformInterface {
  InAppUpdateMePlatform() : super(token: _token);

  static final Object _token = Object();
  static InAppUpdateMePlatform _instance = MethodChannelInAppUpdateMe();

  static InAppUpdateMePlatform get instance => _instance;

  static set instance(InAppUpdateMePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<UpdateInfo?> checkForUpdate({
    bool useStore = true,
    String? updateUrl,
    String? currentVersion,
  }) {
    throw UnimplementedError('checkForUpdate() has not been implemented.');
  }

  Future<bool> startFlexibleUpdate() {
    throw UnimplementedError('startFlexibleUpdate() has not been implemented.');
  }

  Future<bool> startImmediateUpdate() {
    throw UnimplementedError('startImmediateUpdate() has not been implemented.');
  }

  Future<bool> completeFlexibleUpdate() {
    throw UnimplementedError('completeFlexibleUpdate() has not been implemented.');
  }

  Future<bool> downloadAndInstallUpdate(String downloadUrl) {
    throw UnimplementedError('downloadAndInstallUpdate() has not been implemented.');
  }

  Future<bool> isUpdateAvailable() {
    throw UnimplementedError('isUpdateAvailable() has not been implemented.');
  }

  void setUpdateListener(UpdateListener listener) {
    throw UnimplementedError('setUpdateListener() has not been implemented.');
  }
}

class UpdateInfo {
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

  UpdateInfo({
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

  factory UpdateInfo.fromMap(Map<String, dynamic> map) {
    return UpdateInfo(
      updateAvailable: map['updateAvailable'] ?? false,
      immediateUpdateAllowed: map['immediateUpdateAllowed'] ?? false,
      flexibleUpdateAllowed: map['flexibleUpdateAllowed'] ?? false,
      availableVersionCode: map['availableVersionCode'],
      updatePriority: map['updatePriority'],
      appStoreVersion: map['appStoreVersion'],
      currentVersion: map['currentVersion'],
      appStoreUrl: map['appStoreUrl'],
      directUpdate: map['directUpdate'],
      downloadUrl: map['downloadUrl'],
    );
  }
}

abstract class UpdateListener {
  void onUpdateDownloaded();
  void onUpdateInstalled();
  void onUpdateFailed(String error);
  void onUpdateProgress(int progress);
  void onUpdateResult(String result);
}