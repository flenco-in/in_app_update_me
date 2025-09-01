# Testing Guide for in_app_update_me

This guide explains how to test the in_app_update_me plugin at different levels, from unit tests to real-world scenarios.

## 1. 🧪 Unit Tests

### Running Unit Tests
```bash
# From the plugin root directory
flutter test

# Or run specific test files
dart test test/in_app_update_me_test.dart
```

### What's Tested
- ✅ Plugin initialization and configuration
- ✅ Platform method calls
- ✅ Update info parsing
- ✅ Configuration validation
- ✅ Error handling

## 2. 🎯 Integration Tests

### Android Testing

#### Google Play Store Updates
**Requirements:**
- Published app on Google Play Console
- Test using Internal Testing track

**Steps:**
1. **Setup Internal Testing:**
   ```bash
   # Build and upload to Google Play Console (Internal Testing)
   flutter build appbundle --release
   ```

2. **Test Script:**
   ```dart
   // Add to your test app
   Future<void> testPlayStoreUpdate() async {
     final updateInfo = await InAppUpdateMe().checkForUpdate(useStore: true);
     
     if (updateInfo?.updateAvailable == true) {
       // Test immediate update
       await InAppUpdateMe().startImmediateUpdate();
       
       // Test flexible update
       await InAppUpdateMe().startFlexibleUpdate();
     }
   }
   ```

3. **Testing Scenarios:**
   - ✅ No update available
   - ✅ Flexible update available
   - ✅ Immediate update required
   - ✅ High priority updates
   - ✅ Update download progress
   - ✅ Update installation

#### Direct APK Updates
**Requirements:**
- Test server with APK files
- Different version APKs

**Setup Test Server:**
```javascript
// Simple Node.js server for testing
const express = require('express');
const app = express();

// Version check endpoint
app.get('/api/version', (req, res) => {
  res.json({
    version: "1.1.0",
    build: 11,
    priority: 4,
    forceUpdate: false,
    downloadUrl: "http://your-server.com/app-v1.1.0.apk"
  });
});

// APK download endpoint
app.get('/app-v1.1.0.apk', (req, res) => {
  res.download('./app-release.apk');
});

app.listen(3000);
```

**Test Direct Updates:**
```dart
Future<void> testDirectUpdate() async {
  final updateInfo = await InAppUpdateMe().checkForUpdate(
    useStore: false,
    updateUrl: 'http://your-server.com/api/version',
    currentVersion: '1.0.0',
  );
  
  if (updateInfo?.updateAvailable == true) {
    await InAppUpdateMe().downloadAndInstallUpdate(
      updateInfo!.downloadUrl!
    );
  }
}
```

### iOS Testing

#### App Store Updates
**Requirements:**
- App published on App Store
- TestFlight builds with different versions

**Steps:**
1. **TestFlight Setup:**
   - Upload builds with incremental version numbers
   - Use TestFlight for beta testing

2. **Test App Store Check:**
   ```dart
   Future<void> testAppStoreUpdate() async {
     final updateInfo = await InAppUpdateMe().checkForUpdate(useStore: true);
     
     if (updateInfo?.updateAvailable == true) {
       // This will redirect to App Store
       await InAppUpdateMe().openStore();
     }
   }
   ```

#### Enterprise Distribution
**Requirements:**
- Enterprise Developer Account
- Signed IPA files

**Test Enterprise Updates:**
```dart
Future<void> testEnterpriseUpdate() async {
  final success = await InAppUpdateMe().downloadAndInstallUpdate(
    'https://your-enterprise-server.com/app.ipa'
  );
  
  print('Enterprise update result: $success');
}
```

## 3. 🔄 Manual Testing Scenarios

### Force Update Testing
```dart
// Test force update dialog
void testForceUpdate() {
  final updateInfo = AppUpdateInfo(
    updateAvailable: true,
    updatePriority: 5, // Critical priority
    shouldForceUpdate: true,
  );
  
  ForceUpdateDialog.show(
    context,
    updateInfo,
    UpdateConfig(forceUpdate: true),
  );
}
```

### Progress Tracking
```dart
// Test download progress
void testProgressTracking() {
  InAppUpdateMe().setUpdateListener(
    DefaultUpdateListener(
      onProgress: (progress) {
        print('Download progress: $progress%');
        // Update UI with progress
      },
      onDownloaded: () {
        print('Download completed');
      },
      onInstalled: () {
        print('Installation completed');
      },
      onFailed: (error) {
        print('Update failed: $error');
      },
    ),
  );
}
```

## 4. 🏗️ Development Testing

### Mock Testing
Create a mock server for consistent testing:

```dart
class MockUpdateServer {
  static const String baseUrl = 'http://localhost:3000';
  
  static Future<void> startMockServer() async {
    // Start local server for testing
  }
  
  static Map<String, dynamic> getMockUpdateInfo({
    bool updateAvailable = true,
    int priority = 2,
    bool forceUpdate = false,
  }) {
    return {
      'version': '2.0.0',
      'build': 20,
      'priority': priority,
      'forceUpdate': forceUpdate,
      'downloadUrl': '$baseUrl/test-app.apk',
      'releaseNotes': 'Test update with new features'
    };
  }
}
```

### Automated Testing
```dart
// Integration test example
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_app_update_me_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('In-App Update Integration Tests', () {
    testWidgets('Update check flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap on check update button
      await tester.tap(find.text('Check for Store Update'));
      await tester.pumpAndSettle();

      // Verify update dialog appears
      expect(find.text('Update Available'), findsOneWidget);
    });

    testWidgets('Force update flow', (WidgetTester tester) async {
      // Test force update scenario
      app.main();
      await tester.pumpAndSettle();

      // Simulate force update
      await tester.tap(find.text('Test Force Update'));
      await tester.pumpAndSettle();

      // Verify force update dialog
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Later'), findsNothing); // Should not be dismissible
    });
  });
}
```

## 5. 📱 Device Testing

### Android Testing Checklist
- [ ] **Play Store Updates:**
  - [ ] Internal testing track
  - [ ] Production updates
  - [ ] Flexible vs immediate updates
  - [ ] Update priorities

- [ ] **Direct APK Updates:**
  - [ ] Download from server
  - [ ] Install permissions
  - [ ] FileProvider configuration
  - [ ] Progress tracking

- [ ] **Force Updates:**
  - [ ] Non-dismissible dialog
  - [ ] App exit on cancel
  - [ ] Update completion

### iOS Testing Checklist
- [ ] **App Store Updates:**
  - [ ] Version comparison
  - [ ] App Store redirect
  - [ ] TestFlight updates

- [ ] **Enterprise Updates:**
  - [ ] IPA installation
  - [ ] Enterprise certificates
  - [ ] Profile management

- [ ] **Force Updates:**
  - [ ] Blocking UI
  - [ ] Store redirection

## 6. ⚡ Quick Testing Commands

### Development Testing
```bash
# Start example app for testing
cd example
flutter run

# Run on specific device
flutter run -d android
flutter run -d ios

# Build for testing
flutter build apk --debug
flutter build ios --debug
```

### Testing with Different Configurations
```dart
// Test with store updates
InAppUpdateMe().initialize(UpdateConfig(
  useStore: true,
  forceUpdate: false,
  checkInterval: Duration(minutes: 1), // Quick testing
));

// Test with direct updates
InAppUpdateMe().initialize(UpdateConfig(
  useStore: false,
  updateUrl: 'http://your-test-server.com/version',
  forceUpdate: true,
));
```

## 7. 🐛 Debugging Tips

### Common Issues and Solutions

1. **"Update not available" on Android:**
   ```bash
   # Check if app is signed consistently
   flutter build appbundle --release
   
   # Verify Google Play Console setup
   # Ensure version code is incremented
   ```

2. **APK installation blocked:**
   ```xml
   <!-- Add to AndroidManifest.xml -->
   <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
   ```

3. **iOS App Store redirect fails:**
   ```dart
   // Verify bundle ID matches App Store
   final packageInfo = await PackageInfo.fromPlatform();
   print('Bundle ID: ${packageInfo.packageName}');
   ```

### Debug Logging
```dart
// Enable debug mode
InAppUpdateMe().initialize(UpdateConfig(
  debugMode: true, // Add this to your config
));

// Add custom logging
InAppUpdateMe().setUpdateListener(DefaultUpdateListener(
  onProgress: (progress) => print('🔄 Progress: $progress%'),
  onDownloaded: () => print('✅ Downloaded'),
  onInstalled: () => print('🎉 Installed'),
  onFailed: (error) => print('❌ Failed: $error'),
));
```

## 8. 🚀 Production Testing

### Gradual Rollout Testing
1. **Phase 1:** Internal testing (10 users)
2. **Phase 2:** Alpha testing (100 users)
3. **Phase 3:** Beta testing (1000 users)
4. **Phase 4:** Production rollout

### Monitoring
- Monitor crash reports during updates
- Track update success/failure rates
- Monitor app store ratings after updates

## Summary

Testing the in_app_update_me plugin requires:
1. ✅ **Unit tests** for core functionality
2. ✅ **Integration tests** with real stores
3. ✅ **Manual testing** of UI components
4. ✅ **Device testing** on multiple platforms
5. ✅ **Production monitoring** for real-world usage

The plugin provides comprehensive testing capabilities, but real-world testing with actual store distributions is essential for validating the complete update flow.