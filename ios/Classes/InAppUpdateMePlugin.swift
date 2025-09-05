import Flutter
import UIKit
import Foundation

public class InAppUpdateMePlugin: NSObject, FlutterPlugin, URLSessionDownloadDelegate {
    private var channel: FlutterMethodChannel?
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession?
    private var downloadedFileURL: URL?
    private var isFlexibleUpdateDownloading = false
    private var flexibleUpdateInfo: [String: Any]?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "in_app_update_me", binaryMessenger: registrar.messenger())
        let instance = InAppUpdateMePlugin()
        instance.channel = channel
        instance.setupURLSession()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "in_app_update_me.download")
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkForUpdate":
            checkForUpdate(call: call, result: result)
        case "startFlexibleUpdate":
            startFlexibleUpdate(call: call, result: result)
        case "startImmediateUpdate":
            startImmediateUpdate(call: call, result: result)
        case "completeFlexibleUpdate":
            completeFlexibleUpdate(result: result)
        case "downloadAndInstallApk":
            downloadAndInstallIPA(call: call, result: result)
        case "isUpdateAvailable":
            isUpdateAvailable(result: result)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func checkForUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let useAppStore = args["useAppStore"] as? Bool ?? true
        
        if useAppStore {
            checkAppStoreUpdate(result: result)
        } else {
            guard let updateUrl = args["updateUrl"] as? String,
                  let currentVersion = args["currentVersion"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "updateUrl and currentVersion are required for direct updates", details: nil))
                return
            }
            checkDirectUpdate(updateUrl: updateUrl, currentVersion: currentVersion, result: result)
        }
    }
    
    private func checkAppStoreUpdate(result: @escaping FlutterResult) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            result(FlutterError(code: "INVALID_BUNDLE_ID", message: "Cannot get bundle identifier", details: nil))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "NETWORK_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let appInfo = results.first else {
                    result(FlutterError(code: "PARSE_ERROR", message: "Cannot parse App Store response", details: nil))
                    return
                }
                
                let appStoreVersion = appInfo["version"] as? String ?? ""
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                let updateAvailable = self?.isVersionNewer(appStoreVersion: appStoreVersion, currentVersion: currentVersion) ?? false
                
                result([
                    "updateAvailable": updateAvailable,
                    "appStoreVersion": appStoreVersion,
                    "currentVersion": currentVersion,
                    "appStoreUrl": "https://apps.apple.com/app/id\(appInfo["trackId"] as? Int64 ?? 0)",
                    "flexibleUpdateAllowed": false,
                    "immediateUpdateAllowed": true
                ])
            }
        }.resume()
    }
    
    private func checkDirectUpdate(updateUrl: String, currentVersion: String, result: @escaping FlutterResult) {
        guard let url = URL(string: updateUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid update URL", details: nil))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "NETWORK_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                
                result([
                    "updateAvailable": true,
                    "directUpdate": true,
                    "downloadUrl": updateUrl,
                    "currentVersion": currentVersion,
                    "flexibleUpdateAllowed": true,
                    "immediateUpdateAllowed": true
                ])
            }
        }.resume()
    }
    
    private func startFlexibleUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let downloadUrl = args["downloadUrl"] as? String else {
            // For App Store updates, we can't do flexible updates
            redirectToAppStore(result: result)
            return
        }
        
        // For direct updates (enterprise/ad-hoc apps), we can download in background
        startFlexibleDownload(downloadUrl: downloadUrl, result: result)
    }
    
    private func startFlexibleDownload(downloadUrl: String, result: @escaping FlutterResult) {
        guard let url = URL(string: downloadUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid download URL", details: nil))
            return
        }
        
        // Cancel any existing download
        downloadTask?.cancel()
        
        // Start background download
        downloadTask = urlSession?.downloadTask(with: url)
        isFlexibleUpdateDownloading = true
        flexibleUpdateInfo = ["downloadUrl": downloadUrl]
        
        downloadTask?.resume()
        result(true)
        
        // Notify Flutter about download started
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onUpdateDownloadStarted", arguments: nil)
        }
    }
    
    private func startImmediateUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't support immediate updates like Android
        // We'll redirect to App Store for updates
        redirectToAppStore(result: result)
    }
    
    private func completeFlexibleUpdate(result: @escaping FlutterResult) {
        guard let fileURL = downloadedFileURL else {
            result(FlutterError(code: "NO_DOWNLOAD", message: "No downloaded update available", details: nil))
            return
        }
        
        // For iOS, we can't silently install like Android
        // Instead, we'll open the downloaded IPA/enterprise app URL
        if fileURL.pathExtension.lowercased() == "ipa" || 
           fileURL.absoluteString.contains("itms-services") {
            
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(fileURL) {
                    UIApplication.shared.open(fileURL) { success in
                        if success {
                            result(true)
                            // Notify Flutter about installation started
                            DispatchQueue.main.async { [weak self] in
                                self?.channel?.invokeMethod("onUpdateInstallStarted", arguments: nil)
                            }
                        } else {
                            result(FlutterError(code: "INSTALL_FAILED", message: "Cannot install update", details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "CANNOT_OPEN", message: "Cannot open update file", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_FILE", message: "Invalid update file format", details: nil))
        }
    }
    
    private func downloadAndInstallIPA(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't allow direct IPA installation outside of App Store
        // This would be for enterprise apps or TestFlight builds
        guard let args = call.arguments as? [String: Any],
              let downloadUrl = args["downloadUrl"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "downloadUrl is required", details: nil))
            return
        }
        
        // For enterprise apps, we can redirect to the IPA URL
        if let url = URL(string: downloadUrl) {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url) { success in
                        result(success)
                    }
                } else {
                    result(FlutterError(code: "CANNOT_OPEN_URL", message: "Cannot open update URL", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid download URL", details: nil))
        }
    }
    
    private func isUpdateAvailable(result: @escaping FlutterResult) {
        checkAppStoreUpdate { flutterResult in
            if let updateInfo = flutterResult as? [String: Any],
               let updateAvailable = updateInfo["updateAvailable"] as? Bool {
                result(updateAvailable)
            } else {
                result(false)
            }
        }
    }
    
    private func redirectToAppStore(result: @escaping FlutterResult) {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            result(FlutterError(code: "INVALID_BUNDLE_ID", message: "Cannot get bundle identifier", details: nil))
            return
        }
        
        let appStoreUrl = "https://apps.apple.com/app/id\(bundleId)"
        if let url = URL(string: appStoreUrl) {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url) { success in
                        result(success)
                    }
                } else {
                    result(FlutterError(code: "CANNOT_OPEN_APP_STORE", message: "Cannot open App Store", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "INVALID_APP_STORE_URL", message: "Invalid App Store URL", details: nil))
        }
    }
    
    private func isVersionNewer(appStoreVersion: String, currentVersion: String) -> Bool {
        let appStoreComponents = appStoreVersion.components(separatedBy: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(appStoreComponents.count, currentComponents.count)
        
        for i in 0..<maxCount {
            let appStoreNumber = i < appStoreComponents.count ? appStoreComponents[i] : 0
            let currentNumber = i < currentComponents.count ? currentComponents[i] : 0
            
            if appStoreNumber > currentNumber {
                return true
            } else if appStoreNumber < currentNumber {
                return false
            }
        }
        
        return false
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move downloaded file to a permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("in_app_update.ipa")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move downloaded file to permanent location
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            downloadedFileURL = destinationURL
            isFlexibleUpdateDownloading = false
            
            // Notify Flutter about download completion
            DispatchQueue.main.async { [weak self] in
                self?.channel?.invokeMethod("onUpdateDownloaded", arguments: nil)
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.channel?.invokeMethod("onUpdateFailed", arguments: ["error": "Failed to save downloaded file: \(error.localizedDescription)"])
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100) : 0
        
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onUpdateProgress", arguments: ["progress": progress])
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didCompleteWithError error: Error?) {
        if let error = error {
            isFlexibleUpdateDownloading = false
            DispatchQueue.main.async { [weak self] in
                self?.channel?.invokeMethod("onUpdateFailed", arguments: ["error": "Download failed: \(error.localizedDescription)"])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func isFlexibleUpdateAvailable() -> Bool {
        return downloadedFileURL != nil && !isFlexibleUpdateDownloading
    }
    
    func checkFlexibleUpdateDownloading() -> Bool {
        return isFlexibleUpdateDownloading
    }
    
    func cancelFlexibleUpdate() {
        downloadTask?.cancel()
        isFlexibleUpdateDownloading = false
        downloadedFileURL = nil
        flexibleUpdateInfo = nil
    }
}