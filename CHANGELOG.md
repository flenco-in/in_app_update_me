# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-07-03

### Fixed
- **Android/iOS**: `checkForUpdate(useStore: false, ...)` (direct/enterprise updates) now parses the version-check response body as a JSON manifest (`updateAvailable`, `version`, `downloadUrl`, `priority`, `forceUpdate`). Previously `downloadUrl` was always set to the version-check URL itself, so `performUpdateCheck()`, `ForceUpdateDialog`, and `UpdateAvailableDialog` would try to download and install that URL's response body (e.g. a JSON payload) instead of the actual APK/IPA. Falls back to the pre-1.2.0 behaviour (reachable = available, reuse the checked URL) for non-JSON responses.
- **Android**: direct-update responses now set `immediateUpdateAllowed`/`flexibleUpdateAllowed`, matching iOS — previously Android left both unset (defaulting to `false`), so the same server response enabled "Start Immediate/Flexible Update" UI on iOS but not Android.
- **Dart**: `InAppUpdateMe` is a permanent singleton but captured `InAppUpdateMePlatform.instance` once into a `final` field at first construction, permanently ignoring any later `InAppUpdateMePlatform.instance = ...` reassignment — including the standard test-mocking pattern used by this package's own test suite (5 of 8 tests were failing before this fix). `_platform` is now resolved dynamically on each access.
- **Dart**: `DirectUpdateConfig` passed to `performUpdateCheck()` always failed with `INVALID_ARGUMENTS` — the method read the inherited `updateUrl` field, which `DirectUpdateConfig` never sets (it derives `versionCheckUrl` from `serverUrl` + `versionEndpoint` instead). `performUpdateCheck()` now resolves the correct URL, headers and timeout for `DirectUpdateConfig`.
- **Dart**: `ForceUpdateDialog` replaced the app's globally registered update listener in `initState()` and never restored it, so any `onProgress`/`onDownloaded`/etc. callbacks registered elsewhere in the app silently stopped firing forever once the dialog had been shown once. The previous listener is now saved and restored in `dispose()`.
- **Dart**: `UpdateConfig.autoCheckOnAppStart`, `checkInterval`, and `minimumPriority` were declared and documented but never read anywhere. `initialize()` now actually performs an automatic `performUpdateCheck()` when `autoCheckOnAppStart` is true, throttled by `checkInterval`; `performUpdateCheck()` now gates the force-update branch on `minimumPriority` and invokes the listener's `onUpdateCheckCompleted`/`onUpdateNotAvailable` callbacks (previously unreachable dead code).
- **iOS**: the documented `handleEventsForBackgroundURLSession` AppDelegate hook told integrators to call `completionHandler()` immediately, which can cause iOS to reclaim the app before a background download that just completed is actually processed. The plugin now exposes `InAppUpdateMePlugin.backgroundCompletionHandler` and implements `urlSessionDidFinishEvents(forBackgroundURLSession:)` to call it at the correct time.
- **iOS**: the iTunes lookup (`checkForUpdate`/`openStore`) omitted a storefront `country` parameter, so apps not distributed in the US App Store always resolved zero results and reported `updateAvailable: false` even when a real update existed. Now scoped to the device's current region automatically.

### Added
- **Android/iOS**: `checkForUpdate()` / `DirectUpdateConfig` now support optional `headers` and `timeout` for the direct-update version-check request (previously declared on `DirectUpdateConfig` but never forwarded to the native layer).

### Changed
- Updated dependencies: `package_info_plus` (4.2.0 → `>=8.1.2 <11.0.0`), `url_launcher` (^6.2.1 → ^6.3.2), `plugin_platform_interface` (^2.1.7 → ^2.1.8), `flutter_lints` (^3.0.1 → ^5.0.0).
- Updated Android toolchain: AGP 7.3.0 → 8.11.1, Kotlin 1.7.10 → 2.2.20, `compileSdk`/`targetSdk` 33 → 35, Java/Kotlin target 1.8 → 11, `kotlinx-coroutines-android` 1.7.1 → 1.10.2, Gradle wrapper (example) 8.12 → 8.14. Swapped `androidx.appcompat:appcompat` for the lighter `androidx.core:core` (the plugin only needs `FileProvider`).
- Updated iOS minimum deployment target 11.0 → 13.0 (podspec + example), matching current Flutter project templates.
- Minimum supported SDK raised to Dart 3.6.0 / Flutter 3.27.0 (previously Dart 3.0.0), driven by the above dependency floors.
- Plugin `AndroidManifest.xml` no longer declares `REQUEST_INSTALL_PACKAGES` (must be declared by the consuming app if using direct APK installs — was already documented this way) or `INSTALL_PACKAGES` (a system-signature-only permission a third-party app can never hold; had no effect).
- `TESTING_GUIDE.md` and `test_server/` are excluded from the published package via `.pubignore` (still available in the git repo) — they're contributor tooling, not something every consumer needs to download.

### Fixed (build)
- Removed a stale, untouched-since-initial-commit `example/android/app/build.gradle` (Groovy) that coexisted with `example/android/app/build.gradle.kts` (Kotlin DSL). Gradle silently prefers the Groovy file when both exist, so the example had been building against `compileSdkVersion 33`/Kotlin 1.7.10/Java 8 regardless of the `.kts` file's settings.

## [1.1.3] - 2026-07-03

### Fixed
- **Dart**: `removeUpdateListener()` now actually detaches the listener from the method channel — previously native callbacks kept firing after removal.
- **Dart**: `initialize()` no longer replaces a listener already registered via `setUpdateListener()`.
- **Android**: User-cancelled flexible download (`InstallStatus.CANCELED`) is now reported via `onUpdateResult("cancelled")` instead of being silently ignored.
- **Android**: `startImmediateUpdate()` now resumes an interrupted immediate update (`DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS`) as required by Play policy, instead of failing with `UPDATE_NOT_AVAILABLE`.
- **Android/iOS**: Download progress callbacks are throttled to whole-percent changes — previously fired per chunk, flooding the platform channel and UI thread on large downloads.
- **Android**: Background download/check coroutines now run in a plugin-scoped `CoroutineScope` that is cancelled in `onDetachedFromEngine`, so no work leaks past engine detach.
- **iOS**: Removed dead helper methods (`isFlexibleUpdateAvailable`, `checkFlexibleUpdateDownloading`, `cancelFlexibleUpdate`) and unused download-state tracking.
- **Android**: `completeFlexibleUpdate()` no longer hangs the Dart Future indefinitely when `AppUpdateManager` is not yet initialised — now returns an error immediately.
- **Android**: `installStateUpdatedListener` is unregistered before re-registering in `startFlexibleUpdate` to prevent duplicate callbacks on repeated calls.
- **Android**: Removed unused `responseBody` dead code in `checkDirectUpdate`.
- **Android**: Removed unused `pendingResult` field.
- **iOS**: `startFlexibleUpdate` with an `itms-services://` URL now opens it directly via the OS instead of attempting to download it (downloading an IPA and opening it via a `file://` path is blocked by iOS security policy).
- **iOS**: `completeFlexibleUpdate` now correctly triggers the OTA installer via the stored `itms-services://` URL; previously the `itms-services://` check ran against a local `file://` path (dead branch — always false) and installation always failed with `CANNOT_OPEN`.
- **iOS**: `checkAppStoreUpdate` with an app not yet published on the App Store now returns `updateAvailable: false` instead of a misleading `PARSE_ERROR`.

### Changed
- README rewritten: accurate platform behaviour table, correct iOS enterprise OTA flow, AppDelegate hook requirement documented, removed references to non-existent `TESTING_GUIDE.md` and `test_server/`.

## [1.1.2] - 2026-07-03

### Fixed
- **Dart**: `checkForUpdate` now uses `invokeMapMethod` instead of `invokeMethod<Map<String,dynamic>>` — the previous call threw a runtime cast error and always silently returned `null`, breaking the core update-check flow on both platforms.
- **Dart**: `openStore()` on iOS no longer opens a hardcoded placeholder URL; it now delegates to the native layer which resolves the real App Store link via iTunes lookup.
- **Android**: `startImmediateUpdate()` and `startFlexibleUpdate()` no longer fail with `NOT_AVAILABLE` when called without a prior `checkForUpdate`; the `AppUpdateManager` is now lazily created in each method.
- **Android**: Fixed `FileOutputStream` leak in `downloadAndInstallApk` — stream is now closed via Kotlin `.use {}` on both success and error paths.
- **iOS**: `redirectToAppStore` no longer constructs an invalid URL by inserting the bundle identifier where a numeric App Store track id is expected; the correct URL is now resolved via an iTunes lookup.
- **iOS**: `trackId` cast `as? Int64` replaced with a `NSNumber`-safe helper (`appStoreURL(from:)`) that prefers the canonical `trackViewUrl` from the lookup response.

## [1.0.0] - 2024-01-15

### Added
- Initial release of in_app_update_me plugin
- Cross-platform support for Android and iOS
- Google Play In-App Updates API integration
- App Store version checking and redirect
- Direct APK/IPA download and installation support
- Force update functionality with blocking UI
- Flexible update support for Android
- Real-time download progress tracking
- Pre-built UI widgets (ForceUpdateDialog, UpdateAvailableDialog, UpdateProgressDialog)
- Comprehensive configuration options
- Update priority handling
- Custom update listeners
- Background update support
- Enterprise app distribution support
- Comprehensive documentation and examples

### Features
- **Android Features:**
  - Google Play In-App Updates (immediate and flexible)
  - Direct APK download and installation
  - Progress tracking during downloads
  - FileProvider integration for secure APK sharing
  - Background update downloads
  
- **iOS Features:**
  - App Store version checking via iTunes API
  - Automatic App Store redirect
  - Enterprise app distribution support
  - TestFlight integration support
  
- **Cross-platform Features:**
  - Force update dialogs
  - Configurable update checking intervals
  - Priority-based update handling
  - Customizable UI components
  - Update listeners and callbacks
  - Error handling and recovery

### API
- `InAppUpdateMe` class with comprehensive update management
- `UpdateConfig` and `DirectUpdateConfig` for configuration
- `AppUpdateInfo` model for update information
- `UpdateListener` interface for callbacks
- Pre-built UI widgets for common update scenarios
- Platform-specific optimizations

### Documentation
- Comprehensive README with usage examples
- API documentation for all classes and methods
- Platform setup instructions
- Advanced usage scenarios
- Troubleshooting guide
- Contributing guidelines

## [Unreleased]

### Planned
- Server-side update configuration
- A/B testing support for updates
- Update rollback functionality
- Enhanced progress reporting
- Additional UI customization options
- Analytics integration
- Automated testing framework

## [1.1.1] - 2025-09-05

### Fixed
- **Swift Compiler Error**: Fixed "Invalid redeclaration of 'isFlexibleUpdateDownloading()'" by renaming function to `checkFlexibleUpdateDownloading()`
- Resolved naming conflict between property and method in iOS Swift implementation

## [1.1.0] - 2025-09-05

### Added
- **🎉 iOS Flexible Updates Support** - Major new feature!
  - Background download support for enterprise and ad-hoc distributed iOS apps
  - Progress tracking during iOS background downloads
  - Install prompting when download completes
  - Full URLSessionDownloadDelegate implementation
  - New listener events: `onUpdateDownloadStarted()`, `onUpdateInstallStarted()`

### Enhanced
- **Enhanced `startFlexibleUpdate()` method** - Now accepts optional `downloadUrl` parameter for iOS
- **Improved iOS implementation** - Better support for enterprise app distribution
- **Updated example app** - Demonstrates new iOS flexible update capabilities
- **Enhanced documentation** - Complete README update with iOS flexible update examples

### API Changes
- `startFlexibleUpdate()` now accepts optional `downloadUrl` parameter
- Added new listener methods in `UpdateListener` interface
- Updated platform interface to support iOS flexible updates

### iOS Features
- Background downloads with progress tracking (enterprise/ad-hoc apps)
- Install prompting for downloaded updates
- Support for enterprise certificate validation
- Ad-hoc distribution compatibility
- Proper error handling for iOS-specific scenarios

### Documentation
- Comprehensive README update highlighting iOS flexible update support
- New troubleshooting section for iOS-specific issues
- Updated API documentation
- Enhanced usage examples for both platforms

## [1.0.2] - 2025-09-05

### Changed
- Android package/namespace updated to `com.flenco.in_app_update_me`.

## [1.0.1] - 2025-09-05

### Fixed
- Add Android Gradle namespace to `android/build.gradle` to satisfy AGP 7.3+/8+ and fix build failure when used in client apps. No API changes.