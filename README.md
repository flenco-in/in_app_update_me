# in_app_update_me

[![pub.dev](https://img.shields.io/pub/v/in_app_update_me.svg)](https://pub.dev/packages/in_app_update_me)
[![Flutter](https://img.shields.io/badge/Flutter->=3.0.0-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flutter plugin for in-app updates on Android (Google Play In-App Updates API) and iOS (App Store version check + redirect). Supports immediate updates, flexible updates, and direct APK installs.

---

## Platform behaviour at a glance

| Feature | Android | iOS |
|---|---|---|
| Check for update | Play Store API | iTunes lookup |
| Immediate update | Play overlay (blocks app) | Redirect to App Store |
| Flexible update | Background download via Play | `itms-services://` OTA only |
| Direct install | Download APK + system installer | Open URL (enterprise OTA) |

---

## Installation

```yaml
dependencies:
  in_app_update_me: ^1.1.2
```

---

## Android setup

**`android/app/build.gradle`** — minimum SDK 21:
```gradle
defaultConfig {
    minSdkVersion 21
}
```

**`AndroidManifest.xml`** — add permissions:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

**For direct APK installs only** — add FileProvider to `AndroidManifest.xml`:
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
<paths>
    <external-files-path name="external_files" path="." />
</paths>
```

---

## iOS setup

**`ios/Podfile`** — minimum iOS 11:
```ruby
platform :ios, '11.0'
```

**For enterprise/ad-hoc OTA flexible updates** — add to your `AppDelegate.swift` so the system can wake the app when a background download finishes:
```swift
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    completionHandler()
}
```

No extra permissions or entitlements needed for App Store version checking.

---

## Basic usage

```dart
import 'package:in_app_update_me/in_app_update_me.dart';

final updater = InAppUpdateMe();

// Initialize once (e.g. in initState)
updater.initialize(const UpdateConfig(useStore: true));

// Listen to update events
updater.setUpdateListener(DefaultUpdateListener(
  onProgress: (p) => print('$p%'),
  onDownloaded: () => print('ready to install'),
  onFailed: (e) => print('error: $e'),
  onResult: (r) => print('result: $r'),        // "success" | "cancelled" | "failed"
  onDownloadStarted: () => print('iOS: OTA started'),
  onInstallStarted: () => print('iOS: install started'),
));

// Check for update
final info = await updater.checkForUpdate();

if (info?.updateAvailable == true) {
  // Option A — immediate (Android: Play overlay / iOS: App Store)
  await updater.startImmediateUpdate();

  // Option B — flexible (Android: background Play download)
  //            (iOS: requires itms-services:// URL, see below)
  await updater.startFlexibleUpdate();
  // ... user keeps using the app ...
  await updater.completeFlexibleUpdate(); // trigger install
}
```

---

## Config options

```dart
UpdateConfig(
  useStore: true,                          // true = Play Store / App Store
  forceUpdate: false,                      // show ForceUpdateDialog if true
  checkInterval: const Duration(hours: 6),
  showProgressDialog: true,
  minimumPriority: UpdatePriority.low,     // low | medium | high | critical
)
```

---

## Force update

```dart
final info = await updater.checkForUpdate();

if (info != null && (info.shouldForceUpdate || config.forceUpdate)) {
  ForceUpdateDialog.show(
    context,
    info,
    const UpdateConfig(forceUpdate: true),
    onError: (e) => print(e),
  );
}
```

`ForceUpdateDialog` is non-dismissible. Use `UpdateAvailableDialog` for optional updates.

---

## Direct APK install (Android sideloading)

Use this for enterprise Android apps distributed outside the Play Store.

```dart
final info = await updater.checkForUpdate(
  useStore: false,
  updateUrl: 'https://your-server.com/api/version',
  currentVersion: '1.2.0',
);

// The plugin always treats a reachable updateUrl as "update available".
// Your server should only serve the endpoint when an update exists.
if (info?.updateAvailable == true) {
  await updater.downloadAndInstallUpdate('https://your-server.com/app.apk');
}
```

---

## iOS enterprise OTA (flexible updates)

iOS cannot install arbitrary IPA files from a file path. For enterprise/ad-hoc distribution, you need an `itms-services://` URL pointing to your distribution manifest plist.

```dart
// Pass the itms-services URL — the plugin opens it directly via the OS.
await updater.startFlexibleUpdate(
  downloadUrl: 'itms-services://?action=download-manifest&url=https://your-server.com/manifest.plist',
);

// When the user is ready to install:
await updater.completeFlexibleUpdate(); // opens the itms-services URL
```

For App Store apps, `startFlexibleUpdate()` and `startImmediateUpdate()` both redirect to the App Store.

---

## Pre-built widgets

```dart
// Optional update prompt
UpdateAvailableDialog.show(context, info, config,
  onUpdateStarted: () {},
  onUpdateLater: () {},
  onError: (e) {},
);

// Mandatory update — cannot be dismissed
ForceUpdateDialog.show(context, info, config,
  onError: (e) {},
);

// Progress indicator
UpdateProgressDialog.show(context,
  progress: 60,
  message: 'Downloading...',
);
```

---

## Listeners

| Callback | Android | iOS | Description |
|---|---|---|---|
| `onProgress(int)` | ✅ | ✅ | Download progress 0–100 |
| `onDownloaded()` | ✅ | ✅ | Download complete |
| `onInstalled()` | ✅ | – | Play update installed |
| `onFailed(String)` | ✅ | ✅ | Error message |
| `onResult(String)` | ✅ | – | `"success"/"cancelled"/"failed"` from Play dialog |
| `onDownloadStarted()` | – | ✅ | OTA download started |
| `onInstallStarted()` | – | ✅ | OTA install triggered |

---

## Gotchas

**Android**
- Play Store updates only work when the app is installed from the Play Store (not debug builds or sideloads). Use the Play Console internal testing track for testing.
- `startFlexibleUpdate` / `startImmediateUpdate` need `checkForUpdate` to have been called first, OR call them directly (the plugin initialises `AppUpdateManager` lazily).
- `completeFlexibleUpdate` must be called after `onDownloaded` fires, not immediately after `startFlexibleUpdate`.

**iOS**
- `checkForUpdate` hits the iTunes lookup API. If your app is not yet published on the App Store, it returns `updateAvailable: false` (not an error).
- Flexible updates on iOS require `itms-services://` URLs (enterprise/ad-hoc only). Regular App Store apps have no background-download path — the user is redirected to the App Store.
- Background downloads require the `handleEventsForBackgroundURLSession` AppDelegate hook (see iOS setup above).

---

## License

MIT — see [LICENSE](LICENSE).
