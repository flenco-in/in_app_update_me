#!/usr/bin/env node

/**
 * Simple test server for in_app_update_me plugin
 * 
 * Usage:
 *   node server.js [port]
 * 
 * Default port: 3000
 */

const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.argv[2] || 3000;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Mock update configurations
const updateConfigs = {
  // No update available
  'no-update': {
    version: '1.0.0',
    build: 1,
    priority: 0,
    forceUpdate: false,
    updateAvailable: false,
    message: 'You are running the latest version'
  },
  
  // Optional update
  'optional-update': {
    version: '1.1.0',
    build: 11,
    priority: 2,
    forceUpdate: false,
    updateAvailable: true,
    downloadUrl: `http://localhost:${port}/downloads/app-v1.1.0.apk`,
    releaseNotes: 'Bug fixes and performance improvements'
  },
  
  // Force update
  'force-update': {
    version: '1.2.0',
    build: 12,
    priority: 5,
    forceUpdate: true,
    updateAvailable: true,
    downloadUrl: `http://localhost:${port}/downloads/app-v1.2.0.apk`,
    releaseNotes: 'Critical security update - Update required to continue'
  },
  
  // High priority update
  'high-priority': {
    version: '1.3.0',
    build: 13,
    priority: 4,
    forceUpdate: false,
    updateAvailable: true,
    downloadUrl: `http://localhost:${port}/downloads/app-v1.3.0.apk`,
    releaseNotes: 'Important feature update with new capabilities'
  }
};

// Routes

// Version check endpoint
app.get('/api/version/:scenario?', (req, res) => {
  const scenario = req.params.scenario || 'optional-update';
  const config = updateConfigs[scenario];
  
  if (!config) {
    return res.status(404).json({
      error: 'Scenario not found',
      available: Object.keys(updateConfigs)
    });
  }
  
  console.log(`📱 Version check requested - Scenario: ${scenario}`);
  res.json(config);
});

// Download endpoint with progress simulation
app.get('/downloads/:filename', (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(__dirname, 'downloads', filename);
  
  console.log(`⬇️  Download requested: ${filename}`);
  
  // Check if file exists
  if (!fs.existsSync(filePath)) {
    // Create a mock APK file for testing
    const mockApkContent = Buffer.alloc(1024 * 1024, 'Mock APK Content'); // 1MB mock file
    
    // Ensure downloads directory exists
    const downloadsDir = path.dirname(filePath);
    if (!fs.existsSync(downloadsDir)) {
      fs.mkdirSync(downloadsDir, { recursive: true });
    }
    
    fs.writeFileSync(filePath, mockApkContent);
    console.log(`📄 Created mock file: ${filename}`);
  }
  
  const stat = fs.statSync(filePath);
  const fileSize = stat.size;
  
  res.setHeader('Content-Type', 'application/vnd.android.package-archive');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Content-Length', fileSize);
  
  // Simulate slow download for testing progress
  const stream = fs.createReadStream(filePath);
  let downloadedBytes = 0;
  
  stream.on('data', (chunk) => {
    downloadedBytes += chunk.length;
    const progress = Math.round((downloadedBytes / fileSize) * 100);
    console.log(`📊 Download progress: ${progress}%`);
  });
  
  stream.on('end', () => {
    console.log(`✅ Download completed: ${filename}`);
  });
  
  stream.pipe(res);
});

// Test endpoints for different scenarios
app.get('/test/:scenario', (req, res) => {
  const scenario = req.params.scenario;
  const config = updateConfigs[scenario];
  
  if (!config) {
    return res.status(404).json({
      error: 'Scenario not found',
      available: Object.keys(updateConfigs)
    });
  }
  
  res.json({
    message: `Test scenario: ${scenario}`,
    config: config,
    testUrl: `http://localhost:${port}/api/version/${scenario}`,
    downloadUrl: config.downloadUrl
  });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    server: 'in_app_update_me test server',
    status: 'running',
    port: port,
    scenarios: Object.keys(updateConfigs),
    endpoints: {
      versionCheck: '/api/version/:scenario',
      download: '/downloads/:filename',
      test: '/test/:scenario'
    }
  });
});

// Root endpoint with instructions
app.get('/', (req, res) => {
  res.send(`
    <h1>in_app_update_me Test Server</h1>
    <p>Server running on port ${port}</p>
    
    <h2>Available Test Scenarios:</h2>
    <ul>
      ${Object.keys(updateConfigs).map(scenario => 
        `<li><a href="/test/${scenario}">${scenario}</a> - ${updateConfigs[scenario].releaseNotes}</li>`
      ).join('')}
    </ul>
    
    <h2>API Endpoints:</h2>
    <ul>
      <li><code>GET /api/version/:scenario</code> - Version check</li>
      <li><code>GET /downloads/:filename</code> - File download</li>
      <li><code>GET /test/:scenario</code> - Test scenario info</li>
      <li><code>GET /status</code> - Server status</li>
    </ul>
    
    <h2>Usage in Flutter App:</h2>
    <pre><code>
// Check for update
final updateInfo = await InAppUpdateMe().checkForUpdate(
  useStore: false,
  updateUrl: 'http://localhost:${port}/api/version/optional-update',
  currentVersion: '1.0.0',
);

// Test different scenarios:
// - optional-update: Normal update available
// - force-update: Mandatory update
// - high-priority: High priority update
// - no-update: No update available
    </code></pre>
  `);
});

// Error handling
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 in_app_update_me test server started`);
  console.log(`📡 Server: http://localhost:${port}`);
  console.log(`📋 Status: http://localhost:${port}/status`);
  console.log(`🧪 Scenarios: ${Object.keys(updateConfigs).join(', ')}`);
  console.log('');
  console.log('💡 Quick test:');
  console.log(`   curl http://localhost:${port}/api/version/optional-update`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 Server shutting down...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('\n👋 Server shutting down...');
  process.exit(0);
});