import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/update_info.dart';
import '../in_app_update_me.dart';
import '../models/update_config.dart';
import '../listeners/update_listener.dart';

class ForceUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final UpdateConfig config;
  final VoidCallback? onUpdateStarted;
  final Function(String)? onError;
  final bool dismissible;

  const ForceUpdateDialog({
    Key? key,
    required this.updateInfo,
    required this.config,
    this.onUpdateStarted,
    this.onError,
    this.dismissible = false,
  }) : super(key: key);

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();

  /// Show force update dialog that cannot be dismissed
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo,
    UpdateConfig config, {
    VoidCallback? onUpdateStarted,
    Function(String)? onError,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: ForceUpdateDialog(
          updateInfo: updateInfo,
          config: config,
          onUpdateStarted: onUpdateStarted,
          onError: onError,
          dismissible: false,
        ),
      ),
    );
  }
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
  bool _isUpdating = false;
  int _downloadProgress = 0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _setupUpdateListener();
  }

  void _setupUpdateListener() {
    InAppUpdateMe().setUpdateListener(DefaultUpdateListener(
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          _statusMessage = 'Downloading... $progress%';
        });
      },
      onDownloaded: () {
        setState(() {
          _statusMessage = 'Download completed. Installing...';
        });
      },
      onInstalled: () {
        setState(() {
          _statusMessage = 'Update installed successfully!';
        });
        // App will restart after installation
      },
      onFailed: (error) {
        setState(() {
          _isUpdating = false;
          _statusMessage = 'Update failed: $error';
        });
        widget.onError?.call(error);
      },
      onResult: (result) {
        if (result == 'cancelled') {
          // For force updates, we don't allow cancellation
          _startUpdate();
        }
      },
    ));
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _statusMessage = 'Starting update...';
    });

    widget.onUpdateStarted?.call();

    try {
      bool success = false;

      if (widget.config.useStore) {
        if (widget.updateInfo.immediateUpdateAllowed) {
          success = await InAppUpdateMe().startImmediateUpdate();
        } else {
          success = await InAppUpdateMe().openStore();
        }
      } else if (widget.updateInfo.downloadUrl != null) {
        success = await InAppUpdateMe().downloadAndInstallUpdate(
          widget.updateInfo.downloadUrl!,
        );
      }

      if (!success) {
        setState(() {
          _isUpdating = false;
          _statusMessage = 'Failed to start update';
        });
        widget.onError?.call('Failed to start update');
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _statusMessage = 'Update error: $e';
      });
      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Colors.red),
          SizedBox(width: 8),
          Text('Update Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A new version of this app is available and required to continue.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (widget.updateInfo.appStoreVersion != null) ...[
            Text('Current Version: ${widget.updateInfo.currentVersion ?? 'Unknown'}'),
            Text('New Version: ${widget.updateInfo.appStoreVersion}'),
            const SizedBox(height: 16),
          ],
          if (_isUpdating) ...[
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress / 100 : null,
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isUpdating) ...[
          TextButton(
            onPressed: widget.dismissible 
                ? () => Navigator.pop(context) 
                : () => SystemNavigator.pop(),
            child: Text(
              widget.dismissible ? 'Later' : 'Exit App',
              style: TextStyle(
                color: widget.dismissible ? Colors.grey : Colors.red,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Now'),
          ),
        ] else ...[
          const SizedBox(
            width: 100,
            child: Center(
              child: Text('Updating...'),
            ),
          ),
        ],
      ],
    );
  }
}

