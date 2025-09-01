# in_app_update_me

[![pub package](https://img.shields.io/pub/v/in_app_update_me.svg)](https://pub.dev/packages/in_app_update_me)
[![Flutter](https://img.shields.io/badge/Flutter->=3.0.0-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)](https://github.com/your-username/in_app_update_me)

A comprehensive Flutter plugin for in-app updates supporting both Android and iOS with direct update capabilities and force update handling.

## Features

✅ **Cross-platform**: Works on both Android and iOS  
✅ **Play Store Updates**: Google Play In-App Updates API support  
✅ **App Store Updates**: App Store redirect and version checking  
✅ **Direct Updates**: Download and install APK/IPA files directly  
✅ **Force Updates**: Mandatory updates with blocking UI  
✅ **Flexible Updates**: Background downloads (Android)  
✅ **Progress Tracking**: Real-time download progress  
✅ **Customizable UI**: Pre-built dialogs and widgets  
✅ **Priority Levels**: Update importance handling  

## Platform Support

| Platform | Store Updates | Direct Updates | Force Updates | Flexible Updates |
|----------|---------------|----------------|---------------|------------------|
| Android  | ✅ Google Play | ✅ APK Download | ✅ | ✅ |
| iOS      | ✅ App Store   | ✅ Enterprise/TestFlight | ✅ | ❌* |

*iOS doesn't support flexible updates due to platform limitations

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  in_app_update_me: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android Setup

1. **Minimum SDK**: Set `minSdkVersion` to 21 or higher in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

2. **Permissions**: Add required permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

3. **FileProvider** (for direct APK installation): Add to `AndroidManifest.xml`:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

Create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path name="external_files" path="." />
</paths>
```

### iOS Setup

1. **Minimum iOS Version**: Set deployment target to 11.0 or higher
2. **App Store Connect**: Ensure your app is published on App Store for store updates
3. **Enterprise Distribution**: For direct updates, use enterprise distribution or TestFlight

## Usage

### Basic Store Updates

```dart
import 'package:in_app_update_me/in_app_update_me.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final InAppUpdateMe _inAppUpdate = InAppUpdateMe();

  @override
  void initState() {
    super.initState();
    _initializeUpdates();
  }

  void _initializeUpdates() {
    // Initialize the plugin
    _inAppUpdate.initialize(UpdateConfig(
      useStore: true,
      checkInterval: Duration(hours: 24),
      autoCheckOnAppStart: true,
    ));

    // Set up update listener
    _inAppUpdate.setUpdateListener(DefaultUpdateListener(
      onProgress: (progress) => print('Download progress: $progress%'),
      onDownloaded: () => print('Update downloaded'),
      onInstalled: () => print('Update installed'),
      onFailed: (error) => print('Update failed: $error'),
    ));
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await _inAppUpdate.checkForUpdate();
    
    if (updateInfo?.updateAvailable == true) {
      // Show update dialog
      UpdateAvailableDialog.show(
        context,
        updateInfo!,
        UpdateConfig(useStore: true),
      );
    }
  }
}
```

### Force Updates

```dart
Future<void> _performForceUpdateCheck() async {
  final result = await _inAppUpdate.performUpdateCheck(
    UpdateConfig(
      useStore: true,
      forceUpdate: true, // This makes the update mandatory
      minimumPriority: UpdatePriority.high,
    ),
  );

  if (result.updateAvailable && result.updateInfo != null) {
    // Show non-dismissible force update dialog
    ForceUpdateDialog.show(
      context,
      result.updateInfo!,
      UpdateConfig(forceUpdate: true),
    );
  }
}
```

### Direct Updates (APK/IPA)

```dart
Future<void> _checkDirectUpdate() async {
  final updateInfo = await _inAppUpdate.checkForUpdate(
    useStore: false,
    updateUrl: 'https://your-server.com/api/check-update',
    currentVersion: '1.0.0',
  );

  if (updateInfo?.updateAvailable == true) {
    // Download and install directly
    await _inAppUpdate.downloadAndInstallUpdate(
      'https://your-server.com/api/download/app.apk',
    );
  }
}
```

### Custom Configuration

```dart
// Store updates with custom settings
final storeConfig = UpdateConfig(
  useStore: true,
  forceUpdate: false,
  checkInterval: Duration(hours: 6),
  showProgressDialog: true,
  minimumPriority: UpdatePriority.medium,
);

// Direct updates configuration
final directConfig = DirectUpdateConfig(
  serverUrl: 'https://your-update-server.com',
  versionEndpoint: '/api/version',
  downloadEndpoint: '/api/download',
  timeout: Duration(seconds: 30),
  forceUpdate: true,
);
```

## API Reference

### InAppUpdateMe Class

#### Methods

- `initialize(UpdateConfig config)` - Initialize the plugin with configuration
- `checkForUpdate({bool useStore, String? updateUrl, String? currentVersion})` - Check for available updates
- `startFlexibleUpdate()` - Start flexible update (Android only)
- `startImmediateUpdate()` - Start immediate update (Android only)
- `downloadAndInstallUpdate(String downloadUrl)` - Download and install update directly
- `openStore()` - Open Play Store or App Store manually
- `performUpdateCheck(UpdateConfig config)` - Complete update check with configuration

#### Listeners

```dart
_inAppUpdate.setUpdateListener(DefaultUpdateListener(
  onProgress: (progress) {/* Download progress 0-100 */},
  onDownloaded: () {/* Update downloaded */},
  onInstalled: () {/* Update installed */},
  onFailed: (error) {/* Update failed */},
  onResult: (result) {/* Update flow result */},
));
```

### UI Widgets

#### ForceUpdateDialog

Non-dismissible dialog for mandatory updates:

```dart
ForceUpdateDialog.show(
  context,
  updateInfo,
  config,
  onUpdateStarted: () => print('Update started'),
  onError: (error) => print('Error: $error'),
);
```

#### UpdateAvailableDialog

Standard update dialog with options:

```dart
UpdateAvailableDialog.show(
  context,
  updateInfo,
  config,
  onUpdateStarted: () => print('Update started'),
  onUpdateLater: () => print('Update postponed'),
  onError: (error) => print('Error: $error'),
);
```

#### UpdateProgressDialog

Progress dialog for downloads:

```dart
UpdateProgressDialog.show(
  context,
  progress: 75,
  message: 'Downloading update...',
);
```

### Configuration Classes

#### UpdateConfig

```dart
UpdateConfig(
  useStore: true,                           // Use Play Store/App Store
  updateUrl: 'https://...',                // Direct update URL
  forceUpdate: false,                      // Make update mandatory
  checkInterval: Duration(hours: 24),      // Check frequency
  showProgressDialog: true,                // Show download progress
  autoCheckOnAppStart: true,               // Auto-check on app start
  minimumPriority: UpdatePriority.low,     // Minimum update priority
)
```

#### DirectUpdateConfig

```dart
DirectUpdateConfig(
  serverUrl: 'https://your-server.com',
  versionEndpoint: '/api/version',
  downloadEndpoint: '/api/download',
  headers: {'Authorization': 'Bearer token'},
  timeout: Duration(seconds: 30),
)
```

### Models

#### AppUpdateInfo

```dart
class AppUpdateInfo {
  final bool updateAvailable;
  final bool immediateUpdateAllowed;
  final bool flexibleUpdateAllowed;
  final String? appStoreVersion;
  final String? currentVersion;
  final int? updatePriority;
  final String? downloadUrl;
  
  // Helper methods
  bool get isHighPriority;
  bool get shouldForceUpdate;
}
```

#### UpdateResult

```dart
class UpdateResult {
  final bool updateAvailable;
  final bool success;
  final String message;
  final AppUpdateInfo? updateInfo;
  final bool isForceUpdate;
}
```

## Advanced Usage

### Custom Update Server

Implement your own update server with these endpoints:

#### Version Check Endpoint
`GET /api/version`

Response:
```json
{
  "version": "1.2.0",
  "build": 120,
  "priority": 4,
  "forceUpdate": true,
  "downloadUrl": "https://server.com/app.apk",
  "releaseNotes": "Bug fixes and improvements"
}
```

#### Download Endpoint
`GET /api/download`

Returns the APK/IPA file with appropriate headers.

### Background Updates

For Android flexible updates:

```dart
class BackgroundUpdateService {
  static Future<void> startBackgroundUpdate() async {
    final inAppUpdate = InAppUpdateMe();
    
    // Set up listener for background updates
    inAppUpdate.setUpdateListener(DefaultUpdateListener(
      onDownloaded: () async {
        // Update downloaded in background
        // Show notification to user
        await _showUpdateReadyNotification();
      },
      onFailed: (error) {
        // Handle background update failure
        print('Background update failed: $error');
      },
    ));

    // Start flexible update
    await inAppUpdate.startFlexibleUpdate();
  }

  static Future<void> completeUpdate() async {
    await InAppUpdateMe().completeFlexibleUpdate();
  }
}
```

### Testing

1. **Android Testing**:
   - Use internal testing track on Google Play Console
   - Test with different update priorities
   - Verify APK installation permissions

2. **iOS Testing**:
   - Use TestFlight for testing App Store updates
   - Test enterprise distribution for direct updates
   - Verify App Store redirect functionality

3. **Direct Update Testing**:
   - Set up a test server with version API
   - Test download and installation flow
   - Verify progress tracking

## Error Handling

```dart
try {
  final result = await InAppUpdateMe().performUpdateCheck(config);
  
  if (!result.success) {
    // Handle update check failure
    showSnackBar('Update check failed: ${result.message}');
  }
} catch (e) {
  // Handle exceptions
  showSnackBar('Update error: $e');
}
```

## Troubleshooting

### Common Issues

1. **"Update not available" on Android**
   - Ensure app is published on Play Store
   - Check that newer version exists
   - Verify app signing consistency

2. **APK installation blocked**
   - Enable "Install from Unknown Sources"
   - Check FileProvider configuration
   - Verify INSTALL_PACKAGES permission

3. **iOS App Store redirect fails**
   - Verify correct App Store ID
   - Check bundle identifier matches
   - Ensure app is published

### Debug Mode

Enable debug output:

```dart
InAppUpdateMe().initialize(UpdateConfig(
  // ... other config
  debugMode: true, // This would show debug logs
));
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📧 Email: support@example.com
- 🐛 Issues: [GitHub Issues](https://github.com/your-username/in_app_update_me/issues)
- 📖 Documentation: [API Docs](https://pub.dev/documentation/in_app_update_me/)

## Examples

Check out the [example](example/) directory for a complete working example demonstrating all features of the plugin.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.