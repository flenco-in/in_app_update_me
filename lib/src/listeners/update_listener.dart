import '../../in_app_update_me_platform_interface.dart';

abstract class AppUpdateListener extends UpdateListener {
  /// Called when update is successfully downloaded
  @override
  void onUpdateDownloaded() {}

  /// Called when update is successfully installed
  @override
  void onUpdateInstalled() {}

  /// Called when update fails with an error
  @override
  void onUpdateFailed(String error) {}

  /// Called during update download with progress (0-100)
  @override
  void onUpdateProgress(int progress) {}

  /// Called when update flow returns a result
  @override
  void onUpdateResult(String result) {}

  /// Called when update check is completed
  void onUpdateCheckCompleted(bool updateAvailable) {}

  /// Called when user cancels update
  void onUpdateCancelled() {}

  /// Called when update is not available
  void onUpdateNotAvailable() {}
}

class DefaultUpdateListener extends AppUpdateListener {
  final Function()? onDownloaded;
  final Function()? onInstalled;
  final Function(String)? onFailed;
  final Function(int)? onProgress;
  final Function(String)? onResult;
  final Function(bool)? onCheckCompleted;
  final Function()? onCancelled;
  final Function()? onNotAvailable;

  DefaultUpdateListener({
    this.onDownloaded,
    this.onInstalled,
    this.onFailed,
    this.onProgress,
    this.onResult,
    this.onCheckCompleted,
    this.onCancelled,
    this.onNotAvailable,
  });

  @override
  void onUpdateDownloaded() {
    onDownloaded?.call();
  }

  @override
  void onUpdateInstalled() {
    onInstalled?.call();
  }

  @override
  void onUpdateFailed(String error) {
    onFailed?.call(error);
  }

  @override
  void onUpdateProgress(int progress) {
    onProgress?.call(progress);
  }

  @override
  void onUpdateResult(String result) {
    onResult?.call(result);
    
    switch (result) {
      case 'success':
        break;
      case 'cancelled':
        onUpdateCancelled();
        break;
      case 'failed':
        onUpdateFailed('Update failed');
        break;
    }
  }

  @override
  void onUpdateCheckCompleted(bool updateAvailable) {
    onCheckCompleted?.call(updateAvailable);
    if (!updateAvailable) {
      onUpdateNotAvailable();
    }
  }

  @override
  void onUpdateCancelled() {
    onCancelled?.call();
  }

  @override
  void onUpdateNotAvailable() {
    onNotAvailable?.call();
  }
}