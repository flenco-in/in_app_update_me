# Test Server for in_app_update_me

A simple Node.js server for testing the in_app_update_me Flutter plugin without needing real app store distributions.

## Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Start the server:**
   ```bash
   npm start
   ```

3. **Open browser:**
   Visit `http://localhost:3000` for instructions and test scenarios.

## Test Scenarios

The server provides different update scenarios:

### 1. **No Update Available**
```bash
curl http://localhost:3000/api/version/no-update
```

### 2. **Optional Update**
```bash
curl http://localhost:3000/api/version/optional-update
```

### 3. **Force Update**
```bash
curl http://localhost:3000/api/version/force-update
```

### 4. **High Priority Update**
```bash
curl http://localhost:3000/api/version/high-priority
```

## Usage in Flutter

```dart
// Test with local server
final updateInfo = await InAppUpdateMe().checkForUpdate(
  useStore: false,
  updateUrl: 'http://localhost:3000/api/version/optional-update',
  currentVersion: '1.0.0',
);

if (updateInfo?.updateAvailable == true) {
  // Test download and install
  await InAppUpdateMe().downloadAndInstallUpdate(
    updateInfo!.downloadUrl!
  );
}
```

## Configuration

Change port by passing it as argument:
```bash
node server.js 8080
```

## API Endpoints

- `GET /` - Server homepage with instructions
- `GET /status` - Server status and available scenarios
- `GET /api/version/:scenario` - Version check for specific scenario
- `GET /downloads/:filename` - Download files (creates mock APK if needed)
- `GET /test/:scenario` - Get test scenario information