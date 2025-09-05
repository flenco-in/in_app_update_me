# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [1.0.1] - 2025-09-05

### Fixed
- Add Android Gradle namespace to `android/build.gradle` to satisfy AGP 7.3+/8+ and fix build failure when used in client apps. No API changes.