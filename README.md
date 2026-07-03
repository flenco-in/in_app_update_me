# in_app_update_me

[![pub.dev](https://img.shields.io/pub/v/in_app_update_me.svg)](https://pub.dev/packages/in_app_update_me)
[![Flutter](https://img.shields.io/badge/Flutter->=3.27.0-blue.svg)](https://flutter.dev/)
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
  in_app_update_me: ^1.2.0
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

**`ios/Podfile`** — minimum iOS 13:
```ruby
platform :ios, '13.0'
```

**For enterprise/ad-hoc OTA flexible updates** — add to your `AppDelegate.swift` so the system can wake the app when a background download finishes. Store the completion handler rather than calling it immediately — it must only run after the background session has finished delivering its events, or a download that completed while the app was suspended/killed can be lost:
```swift
import in_app_update_me

override func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    InAppUpdateMePlugin.backgroundCompletionHandler = completionHandler
}
```

No extra permissions or entitlements needed for App Store version checking.

---

## Basic usage

```dart
import 'package:in_app_update_me/in_app_update_me.dart';

final updater = InAppUpdateMe();

// Register the listener first so the automatic check below can reach it.
updater.setUpdateListener(DefaultUpdateListener(
  onCheckCompleted: (available) => print('update available: $available'),
  onProgress: (p) => print('$p%'),
  onDownloaded: () => print('ready to install'),
  onFailed: (e) => print('error: $e'),
  onResult: (r) => print('result: $r'),        // "success" | "cancelled" | "failed"
  onDownloadStarted: () => print('iOS: OTA started'),
  onInstallStarted: () => print('iOS: install started'),
));

// initialize() checks for an update immediately by default
// (UpdateConfig.autoCheckOnAppStart) and reports back via the listener
// above. Pass autoCheckOnAppStart: false to disable and drive checks
// manually instead (e.g. from a "Check for updates" button).
updater.initialize(const UpdateConfig(useStore: true));

// A manual check works the same way at any time:
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
  forceUpdate: false,                      // gate for the force-update branch of performUpdateCheck()
  autoCheckOnAppStart: true,               // initialize() calls performUpdateCheck() immediately when true
  checkInterval: const Duration(hours: 6), // throttles that automatic check, not manual calls
  showProgressDialog: true,                // reserved — the plugin never shows UI on its own; see Pre-built widgets
  minimumPriority: UpdatePriority.low,     // low | medium | high | critical — floor below which forceUpdate is ignored
)
```

`initialize(config)` is synchronous; when `autoCheckOnAppStart` is true it fires `performUpdateCheck()` in the background and delivers the result through the registered listener's `onUpdateCheckCompleted`/`onUpdateNotAvailable` callbacks, not a return value. `checkInterval` only throttles this automatic path — explicit `checkForUpdate()`/`performUpdateCheck()` calls (e.g. a manual "Check for updates" button) always run immediately. The throttle is in-memory only and resets on app restart.

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

Use this for enterprise Android/iOS apps distributed outside the Play Store / App Store.

`checkForUpdate(useStore: false, updateUrl: ...)` hits your `updateUrl` and, if the response body is JSON, reads it as a manifest:

```json
{
  "updateAvailable": true,
  "version": "1.2.0",
  "downloadUrl": "https://your-server.com/app.apk",
  "priority": 5,
  "forceUpdate": true
}
```

All keys are optional. If the response isn't JSON, or a key is missing, the plugin falls back to: `updateAvailable: true` (reachable = available) and `downloadUrl` equal to `updateUrl` itself — so a server that just returns 200/404 with no body still works, but can't drive `AppUpdateInfo.downloadUrl` to a different URL than the one you checked, and can't drive `shouldForceUpdate`/priority. The bundled [`test_server`](test_server/) implements this manifest shape.

```dart
final info = await updater.checkForUpdate(
  useStore: false,
  updateUrl: 'https://your-server.com/api/version',
  currentVersion: '1.2.0',
  headers: {'Authorization': 'Bearer <token>'}, // optional
  timeout: const Duration(seconds: 15),          // optional
);

if (info?.updateAvailable == true) {
  await updater.downloadAndInstallUpdate(info!.downloadUrl ?? 'https://your-server.com/app.apk');
}
```

`DirectUpdateConfig` builds `updateUrl`/`headers`/`timeout` for you from `serverUrl` + `versionEndpoint`, and works directly with `performUpdateCheck()`:

```dart
final result = await updater.performUpdateCheck(const DirectUpdateConfig(
  serverUrl: 'https://your-server.com',
  versionEndpoint: '/api/version',
  forceUpdate: true, // only takes effect if the manifest's priority/forceUpdate meets minimumPriority
));
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
- `checkForUpdate` hits the iTunes lookup API, scoped to the device's current region automatically. If your app is not yet published on the App Store (or not published in that region), it returns `updateAvailable: false` (not an error).
- Flexible updates on iOS require `itms-services://` URLs (enterprise/ad-hoc only). Regular App Store apps have no background-download path — the user is redirected to the App Store.
- Background downloads require the `handleEventsForBackgroundURLSession` AppDelegate hook (see iOS setup above), otherwise a download that finishes while the app is suspended or killed may not be reported.

**Both platforms**
- `ForceUpdateDialog` temporarily replaces your registered listener (to drive its own progress UI) and restores your previous one when the dialog is dismissed — you don't need to call `setUpdateListener` again afterward.

---

## License

MIT — see [LICENSE](LICENSE).
