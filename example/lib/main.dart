import 'package:flutter/material.dart';
import 'package:in_app_update_me/in_app_update_me.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In-App Update Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'In-App Update Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final InAppUpdateMe _inAppUpdate = InAppUpdateMe();
  String _platformVersion = 'Unknown';
  String _updateStatus = 'No update check performed';
  AppUpdateInfo? _lastUpdateInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePlugin();
    _getPlatformVersion();
  }

  void _initializePlugin() {
    // Initialize with default configuration
    _inAppUpdate.initialize(
      const UpdateConfig(
        useStore: true,
        forceUpdate: false,
        checkInterval: Duration(hours: 1),
        showProgressDialog: true,
        autoCheckOnAppStart: false, // Disabled for demo
      ),
    );

    // Set up update listener
    _inAppUpdate.setUpdateListener(
      DefaultUpdateListener(
        onProgress: (progress) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download progress: $progress%')),
          );
        },
        onDownloaded: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update downloaded! Installing...')),
          );
        },
        onInstalled: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update installed successfully!')),
          );
        },
        onFailed: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: $error')),
          );
        },
        onResult: (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update result: $result')),
          );
        },
      ),
    );
  }

  Future<void> _getPlatformVersion() async {
    final version = await _inAppUpdate.getPlatformVersion();
    setState(() {
      _platformVersion = version ?? 'Unknown platform version';
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isLoading = true;
      _updateStatus = 'Checking for updates...';
    });

    try {
      final updateInfo = await _inAppUpdate.checkForUpdate(useStore: true);
      
      setState(() {
        _isLoading = false;
        _lastUpdateInfo = updateInfo;
        if (updateInfo != null) {
          _updateStatus = updateInfo.updateAvailable 
              ? 'Update available!' 
              : 'No update available';
        } else {
          _updateStatus = 'Update check failed';
        }
      });

      if (updateInfo?.updateAvailable == true) {
        _showUpdateDialog(updateInfo!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _updateStatus = 'Update check failed: $e';
      });
    }
  }

  Future<void> _checkForDirectUpdate() async {
    setState(() {
      _isLoading = true;
      _updateStatus = 'Checking for direct updates...';
    });

    try {
      // Example direct update URL (replace with your actual server)
      final updateInfo = await _inAppUpdate.checkForUpdate(
        useStore: false,
        updateUrl: 'https://your-server.com/api/check-update',
        currentVersion: '1.0.0',
      );
      
      setState(() {
        _isLoading = false;
        _lastUpdateInfo = updateInfo;
        if (updateInfo != null) {
          _updateStatus = updateInfo.updateAvailable 
              ? 'Direct update available!' 
              : 'No direct update available';
        } else {
          _updateStatus = 'Direct update check failed';
        }
      });

      if (updateInfo?.updateAvailable == true) {
        _showUpdateDialog(updateInfo!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _updateStatus = 'Direct update check failed: $e';
      });
    }
  }

  void _showUpdateDialog(AppUpdateInfo updateInfo) {
    if (updateInfo.shouldForceUpdate) {
      ForceUpdateDialog.show(
        context,
        updateInfo,
        const UpdateConfig(forceUpdate: true),
        onUpdateStarted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Force update started')),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Force update error: $error')),
          );
        },
      );
    } else {
      UpdateAvailableDialog.show(
        context,
        updateInfo,
        const UpdateConfig(),
        onUpdateStarted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update started')),
          );
        },
        onUpdateLater: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update postponed')),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update error: $error')),
          );
        },
      );
    }
  }

  Future<void> _startFlexibleUpdate() async {
    if (_lastUpdateInfo?.flexibleUpdateAllowed == true) {
      final success = await _inAppUpdate.startFlexibleUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Flexible update started' 
                : 'Failed to start flexible update'
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flexible update not available')),
      );
    }
  }

  Future<void> _startImmediateUpdate() async {
    if (_lastUpdateInfo?.immediateUpdateAllowed == true) {
      final success = await _inAppUpdate.startImmediateUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Immediate update started' 
                : 'Failed to start immediate update'
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Immediate update not available')),
      );
    }
  }

  Future<void> _openStore() async {
    final success = await _inAppUpdate.openStore();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success 
              ? 'Store opened' 
              : 'Failed to open store'
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Running on: $_platformVersion'),
                    const SizedBox(height: 8),
                    Text('Update Status: $_updateStatus'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_lastUpdateInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Update Check',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Update Available: ${_lastUpdateInfo!.updateAvailable}'),
                      if (_lastUpdateInfo!.currentVersion != null)
                        Text('Current Version: ${_lastUpdateInfo!.currentVersion}'),
                      if (_lastUpdateInfo!.appStoreVersion != null)
                        Text('Store Version: ${_lastUpdateInfo!.appStoreVersion}'),
                      if (_lastUpdateInfo!.updatePriority != null)
                        Text('Priority: ${_lastUpdateInfo!.updatePriority}'),
                      Text('Immediate Update Allowed: ${_lastUpdateInfo!.immediateUpdateAllowed}'),
                      Text('Flexible Update Allowed: ${_lastUpdateInfo!.flexibleUpdateAllowed}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkForUpdate,
                    child: _isLoading 
                        ? const CircularProgressIndicator()
                        : const Text('Check for Store Update'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkForDirectUpdate,
                    child: const Text('Check for Direct Update'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _lastUpdateInfo?.flexibleUpdateAllowed == true 
                        ? _startFlexibleUpdate 
                        : null,
                    child: const Text('Start Flexible Update'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _lastUpdateInfo?.immediateUpdateAllowed == true 
                        ? _startImmediateUpdate 
                        : null,
                    child: const Text('Start Immediate Update'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _openStore,
                    child: const Text('Open Store Manually'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}