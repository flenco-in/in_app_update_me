# in_app_update_me

<div align="center">
  <img src="https://flenco.in/wp-content/uploads/2023/09/cropped-flenco-2023.png" alt="Flenco Logo" height="80" />
  
  [![Flutter](https://img.shields.io/badge/Flutter->=3.0.0-blue.svg)](https://flutter.dev/)
  [![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)]()
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  
  **A comprehensive Flutter plugin for in-app updates supporting both Android and iOS with direct update capabilities and force update handling.**

  [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-atishpaul-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/atishpaul)
</div>

---

## ✨ Features

✅ **Cross-platform**: Works on both Android and iOS  
✅ **Play Store Updates**: Google Play In-App Updates API support  
✅ **App Store Updates**: App Store redirect and version checking  
✅ **Direct Updates**: Download and install APK/IPA files directly  
✅ **Force Updates**: Mandatory updates with blocking UI  
✅ **Flexible Updates**: Background downloads (Android & iOS)  
✅ **Progress Tracking**: Real-time download progress  
✅ **Customizable UI**: Pre-built dialogs and widgets  
✅ **Priority Levels**: Update importance handling  

## 📱 Platform Support

| Platform | Store Updates | Direct Updates | Force Updates | Flexible Updates |
|----------|---------------|----------------|---------------|------------------|
| Android  | ✅ Google Play | ✅ APK Download | ✅ | ✅ Background |
| iOS      | ✅ App Store   | ✅ Enterprise/Ad-hoc | ✅ | ✅ Background* |

*iOS flexible updates work for enterprise and ad-hoc distributed apps with background downloads

## 🍎 iOS Flexible Updates

iOS flexible updates are now supported for enterprise and ad-hoc distributed apps! Here's how it works:

### **App Store Apps**
- Version checking via iTunes API
- Redirects to App Store for updates
- No background downloads (Apple restriction)

### **Enterprise/Ad-hoc Apps**
- ✅ Background downloads with progress tracking
- ✅ Install prompting when download completes
- ✅ Works with internal distribution and TestFlight
- ✅ Full flexible update experience like Android

### **Usage Example for iOS Enterprise Apps**
```dart
// Check for enterprise app update
final updateInfo = await InAppUpdateMe().checkForUpdate(
  useStore: false,
  updateUrl: 'https://your-enterprise-server.com/api/version',
);

if (updateInfo?.flexibleUpdateAllowed == true) {
  // Start background download
  await InAppUpdateMe().startFlexibleUpdate(
    downloadUrl: updateInfo?.downloadUrl,
  );
  
  // User continues using app while download happens
  // When ready, complete the installation
  await InAppUpdateMe().completeFlexibleUpdate();
}
```

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  in_app_update_me: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Basic Setup

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
      onDownloadStarted: () => print('iOS: Background download started'),
      onInstallStarted: () => print('iOS: Installation started'),
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

### 2. Force Updates

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

### 3. Flexible Updates (Android & iOS)

```dart
Future<void> _startFlexibleUpdate() async {
  final updateInfo = await _inAppUpdate.checkForUpdate();
  
  if (updateInfo?.flexibleUpdateAllowed == true) {
    // Android: Uses Google Play In-App Updates
    // iOS: Downloads in background for enterprise/ad-hoc apps
    await _inAppUpdate.startFlexibleUpdate(
      downloadUrl: updateInfo?.downloadUrl, // Required for iOS direct updates
    );
    
    // User can continue using the app while update downloads
    // Complete installation when ready
    await _inAppUpdate.completeFlexibleUpdate();
  }
}
```

### 4. Direct Updates (APK/IPA)

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
      updateInfo!.downloadUrl!,
    );
  }
}
```

## ⚙️ Platform Setup

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
<application>
  <!-- ... other content ... -->
  
  <provider
      android:name="androidx.core.content.FileProvider"
      android:authorities="${applicationId}.fileprovider"
      android:exported="false"
      android:grantUriPermissions="true">
      <meta-data
          android:name="android.support.FILE_PROVIDER_PATHS"
          android:resource="@xml/file_paths" />
  </provider>
</application>
```

Create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path name="external_files" path="." />
</paths>
```

### iOS Setup

1. **Minimum iOS Version**: Set deployment target to 11.0 or higher in `ios/Podfile`:

```ruby
platform :ios, '11.0'
```

2. **App Store Updates**: Ensure your app is published on App Store Connect
3. **Enterprise/Ad-hoc Updates**: For flexible updates and direct installations:
   - Use Apple Enterprise Developer Program for enterprise distribution
   - Use Ad-hoc distribution for testing with limited devices
   - Configure proper provisioning profiles and certificates
4. **Background App Refresh**: Enable for background downloads (optional)

## 🎯 Complete Usage Guide

### Configuration Options

```dart
// Store updates with custom settings
final storeConfig = UpdateConfig(
  useStore: true,                           // Use Play Store/App Store
  forceUpdate: false,                      // Make update mandatory
  checkInterval: Duration(hours: 6),       // Check frequency
  showProgressDialog: true,                // Show download progress
  autoCheckOnAppStart: true,               // Auto-check on app start
  minimumPriority: UpdatePriority.medium,  // Minimum update priority
);

// Direct updates configuration
final directConfig = DirectUpdateConfig(
  serverUrl: 'https://your-update-server.com',
  versionEndpoint: '/api/version',
  downloadEndpoint: '/api/download',
  headers: {'Authorization': 'Bearer token'},
  timeout: Duration(seconds: 30),
  forceUpdate: true,
);
```

### UI Widgets

#### ForceUpdateDialog - Non-dismissible dialog for mandatory updates

```dart
ForceUpdateDialog.show(
  context,
  updateInfo,
  UpdateConfig(forceUpdate: true),
  onUpdateStarted: () => print('Force update started'),
  onError: (error) => print('Error: $error'),
);
```

#### UpdateAvailableDialog - Standard update dialog with options

```dart
UpdateAvailableDialog.show(
  context,
  updateInfo,
  UpdateConfig(useStore: true),
  onUpdateStarted: () => print('Update started'),
  onUpdateLater: () => print('Update postponed'),
  onError: (error) => print('Error: $error'),
);
```

#### UpdateProgressDialog - Progress dialog for downloads

```dart
UpdateProgressDialog.show(
  context,
  progress: 75,
  message: 'Downloading update...',
);
```

## 📋 API Reference

### InAppUpdateMe Methods

| Method | Description | Platforms |
|--------|-------------|-----------|
| `initialize(UpdateConfig config)` | Initialize the plugin with configuration | Android, iOS |
| `checkForUpdate({bool useStore, String? updateUrl, String? currentVersion})` | Check for available updates | Android, iOS |
| `startFlexibleUpdate({String? downloadUrl})` | Start flexible update with optional download URL | Android, iOS |
| `startImmediateUpdate()` | Start immediate update | Android, iOS |
| `downloadAndInstallUpdate(String downloadUrl)` | Download and install update directly | Android, iOS |
| `openStore()` | Open Play Store or App Store manually | Android, iOS |
| `performUpdateCheck(UpdateConfig config)` | Complete update check with configuration | Android, iOS |

### Update Listeners

```dart
_inAppUpdate.setUpdateListener(DefaultUpdateListener(
  onProgress: (progress) {
    // Download progress 0-100
    print('Progress: $progress%');
  },
  onDownloaded: () {
    // Update downloaded successfully
    print('Update ready to install');
  },
  onInstalled: () {
    // Update installed successfully
    print('Update completed');
  },
  onFailed: (error) {
    // Update failed
    print('Update failed: $error');
  },
  onResult: (result) {
    // Update flow result (success, cancelled, failed)
    print('Update result: $result');
  },
  onDownloadStarted: () {
    // iOS: Background download started
    print('iOS: Download started in background');
  },
  onInstallStarted: () {
    // iOS: Installation process started
    print('iOS: Installation started');
  },
));
```

## 🔧 Advanced Usage

### Custom Update Server

For direct updates, implement your own update server with these endpoints:

#### Version Check Endpoint: `GET /api/version`

```json
{
  "version": "1.2.0",
  "build": 120,
  "priority": 4,
  "forceUpdate": true,
  "downloadUrl": "https://your-server.com/app.apk",
  "releaseNotes": "Critical security update - Update required to continue"
}
```

#### Download Endpoint: `GET /api/download`

Returns the APK/IPA file with appropriate headers:
- `Content-Type: application/vnd.android.package-archive` (for APK)
- `Content-Disposition: attachment; filename="app.apk"`

### Background Updates (Android & iOS)

```dart
class BackgroundUpdateService {
  static Future<void> startBackgroundUpdate() async {
    final inAppUpdate = InAppUpdateMe();
    
    // Check for updates first
    final updateInfo = await inAppUpdate.checkForUpdate();
    
    if (updateInfo?.flexibleUpdateAllowed == true) {
      // Set up listener for background updates
      inAppUpdate.setUpdateListener(DefaultUpdateListener(
        onDownloadStarted: () {
          // iOS: Background download started
          print('Background download started');
        },
        onDownloaded: () async {
          // Update downloaded in background
          showUpdateReadyNotification();
        },
        onFailed: (error) {
          print('Background update failed: $error');
        },
      ));

      // Start flexible update
      // For iOS enterprise/ad-hoc apps, pass download URL
      await inAppUpdate.startFlexibleUpdate(
        downloadUrl: updateInfo?.downloadUrl,
      );
    }
  }

  static Future<void> completeUpdate() async {
    await InAppUpdateMe().completeFlexibleUpdate();
  }
}
```

## 🧪 Testing

The plugin includes a complete testing setup:

1. **Unit Tests**: Core functionality testing
2. **Integration Tests**: Real-world scenario testing
3. **Test Server**: Mock server for development testing

### Quick Test Setup

```bash
# 1. Start test server
cd test_server
npm install
npm start

# 2. Run example app  
cd ../example
flutter run

# 3. Test with local server:
# http://localhost:3000/api/version/optional-update
```

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed testing instructions.

## 🐛 Error Handling

```dart
try {
  final result = await InAppUpdateMe().performUpdateCheck(config);
  
  if (!result.success) {
    // Handle update check failure
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Update check failed: ${result.message}')),
    );
  }
} catch (e) {
  // Handle exceptions
  print('Update error: $e');
}
```

## 🔍 Troubleshooting

### Common Issues

#### Android Issues

1. **"Update not available" on Google Play**
   - Ensure app is published on Play Store (at least in Internal Testing)
   - Verify that a newer version exists with higher `versionCode`
   - Check app signing consistency between versions

2. **APK installation blocked**
   - Enable "Install from Unknown Sources" in device settings
   - Verify FileProvider configuration in AndroidManifest.xml
   - Check `REQUEST_INSTALL_PACKAGES` permission

3. **Flexible update not working**
   - Ensure Google Play In-App Updates dependency is added
   - Test with internal testing track, not debug builds
   - Verify minimum API level 21

#### iOS Issues

1. **App Store redirect fails**
   - Verify correct bundle identifier
   - Ensure app is published on App Store
   - Check network connectivity

2. **Enterprise distribution issues**
   - Verify enterprise certificate validity
   - Check device management profile
   - Ensure IPA is properly signed

3. **Flexible update not working on iOS**
   - Ensure you're using enterprise or ad-hoc distribution (not App Store)
   - Verify downloadUrl is provided in `startFlexibleUpdate()`
   - Check that the IPA URL is accessible and properly signed
   - Test with proper provisioning profiles

### Debug Mode

Enable detailed logging:

```dart
InAppUpdateMe().initialize(UpdateConfig(
  // ... other config
  showProgressDialog: true,
  // Add custom logging in listeners
));

InAppUpdateMe().setUpdateListener(DefaultUpdateListener(
  onProgress: (progress) => print('🔄 Download: $progress%'),
  onDownloaded: () => print('✅ Download complete'),
  onInstalled: () => print('🎉 Installation complete'),
  onFailed: (error) => print('❌ Error: $error'),
));
```

## 📖 Example App

The plugin includes a comprehensive example app that demonstrates all features:

```bash
cd example
flutter run
```

Features demonstrated:
- ✅ Store update checking
- ✅ Direct update checking
- ✅ Force update dialogs
- ✅ Progress tracking
- ✅ Error handling
- ✅ Different update scenarios

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💝 Support the Project

If this plugin helped you, consider buying me a coffee! ☕

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-atishpaul-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/atishpaul)

## 🏢 About Flenco

This plugin is created and maintained by **Flenco**, a software development company specializing in mobile app development.

**Website**: [https://flenco.in](https://flenco.in)

---

## 📚 Additional Resources

- [Complete Example App](example/) - Full implementation example
- [Testing Guide](TESTING_GUIDE.md) - Comprehensive testing instructions  
- [Test Server](test_server/) - Mock server for development testing
- [Changelog](CHANGELOG.md) - Version history and changes

---

<div align="center">
  Made with ❤️ by <a href="https://flenco.in">Flenco</a>
  
  <img src="https://flenco.in/wp-content/uploads/2023/09/cropped-flenco-2023.png" alt="Flenco Logo" height="40" />
</div>