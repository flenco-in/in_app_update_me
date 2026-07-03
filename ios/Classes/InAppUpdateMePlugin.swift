import Flutter
import UIKit
import Foundation

public class InAppUpdateMePlugin: NSObject, FlutterPlugin, URLSessionDownloadDelegate {
    private var channel: FlutterMethodChannel?
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession?
    private var downloadedFileURL: URL?
    private var flexibleUpdateInfo: [String: Any]?
    private var lastReportedProgress = -1

    /// Set by the host app's AppDelegate from
    /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    /// Must be called only after the background session finishes delivering
    /// all queued delegate events (see `urlSessionDidFinishEvents`) — calling
    /// it immediately can cause iOS to reclaim the app before a download that
    /// completed in the background is actually processed.
    public static var backgroundCompletionHandler: (() -> Void)?

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
            let headers = args["headers"] as? [String: String]
            let timeoutMs = args["timeoutMs"] as? Int
            checkDirectUpdate(updateUrl: updateUrl, currentVersion: currentVersion, headers: headers, timeoutMs: timeoutMs, result: result)
        }
    }
    
    /// Builds the iTunes lookup URL, scoped to the device's storefront
    /// country when known. Without this, apps not distributed in the US
    /// store return zero results from the bare bundleId lookup and always
    /// report "no update available" even when one exists.
    private static func iTunesLookupURL(bundleId: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        var queryItems = [URLQueryItem(name: "bundleId", value: bundleId)]
        if let country = Locale.current.regionCode {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    private func checkAppStoreUpdate(result: @escaping FlutterResult) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = InAppUpdateMePlugin.iTunesLookupURL(bundleId: bundleId) else {
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
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    result(FlutterError(code: "PARSE_ERROR", message: "Cannot parse App Store response", details: nil))
                    return
                }

                let results = json["results"] as? [[String: Any]] ?? []
                guard let appInfo = results.first else {
                    // App not found — either not published yet or wrong bundle id.
                    result([
                        "updateAvailable": false,
                        "currentVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                        "immediateUpdateAllowed": false,
                        "flexibleUpdateAllowed": false
                    ])
                    return
                }
                
                let appStoreVersion = appInfo["version"] as? String ?? ""
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                let updateAvailable = self?.isVersionNewer(appStoreVersion: appStoreVersion, currentVersion: currentVersion) ?? false
                let appStoreUrl = InAppUpdateMePlugin.appStoreURL(from: appInfo) ?? ""

                result([
                    "updateAvailable": updateAvailable,
                    "appStoreVersion": appStoreVersion,
                    "currentVersion": currentVersion,
                    "appStoreUrl": appStoreUrl,
                    "flexibleUpdateAllowed": false,
                    "immediateUpdateAllowed": true
                ])
            }
        }.resume()
    }
    
    private func checkDirectUpdate(updateUrl: String, currentVersion: String, headers: [String: String]?, timeoutMs: Int?, result: @escaping FlutterResult) {
        guard let url = URL(string: updateUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid update URL", details: nil))
            return
        }

        var request = URLRequest(url: url)
        headers?.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }
        if let timeoutMs = timeoutMs, timeoutMs > 0 {
            request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "NETWORK_ERROR", message: error.localizedDescription, details: nil))
                    return
                }

                // The response body may be a JSON manifest (as served by the
                // bundled test_server) describing the real download location,
                // version and priority. If it isn't JSON — or lacks these
                // keys — fall back to treating "reachable" as "update
                // available" and reuse updateUrl, matching the plugin's
                // original behaviour for servers that just 200/404 on the
                // version endpoint.
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) as? [String: Any] }

                let updateAvailable = json?["updateAvailable"] as? Bool ?? true
                let downloadUrl = (json?["downloadUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? updateUrl
                let latestVersion = (json?["version"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let forceUpdate = json?["forceUpdate"] as? Bool ?? false
                let priority = (json?["priority"] as? Int) ?? (forceUpdate ? 5 : 0)

                var payload: [String: Any] = [
                    "updateAvailable": updateAvailable,
                    "directUpdate": true,
                    "downloadUrl": downloadUrl,
                    "currentVersion": currentVersion,
                    "updatePriority": priority,
                    "flexibleUpdateAllowed": updateAvailable,
                    "immediateUpdateAllowed": updateAvailable
                ]
                if let latestVersion = latestVersion {
                    payload["appStoreVersion"] = latestVersion
                }
                result(payload)
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

        // itms-services:// is Apple's OTA install scheme — it must be handed
        // directly to the OS; downloading the IPA ourselves won't work because
        // iOS refuses to install arbitrary IPA files from a file:// path.
        if downloadUrl.hasPrefix("itms-services://") {
            flexibleUpdateInfo = ["downloadUrl": downloadUrl]
            result(true)
            DispatchQueue.main.async { [weak self] in
                self?.channel?.invokeMethod("onUpdateDownloadStarted", arguments: nil)
            }
            return
        }

        // For other URLs, download in the background (e.g., enterprise manifest
        // plist served via https that the system will open via itms-services).
        downloadTask?.cancel()
        downloadTask = urlSession?.downloadTask(with: url)
        flexibleUpdateInfo = ["downloadUrl": downloadUrl]
        lastReportedProgress = -1
        downloadTask?.resume()
        result(true)
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
        // If the update was initiated via an itms-services:// URL, hand it to
        // the OS now — this triggers Apple's built-in OTA installer.
        if let storedUrl = flexibleUpdateInfo?["downloadUrl"] as? String,
           storedUrl.hasPrefix("itms-services://"),
           let url = URL(string: storedUrl) {
            DispatchQueue.main.async { [weak self] in
                UIApplication.shared.open(url) { success in
                    if success {
                        self?.channel?.invokeMethod("onUpdateInstallStarted", arguments: nil)
                        result(true)
                    } else {
                        result(FlutterError(code: "INSTALL_FAILED", message: "Cannot open itms-services URL", details: nil))
                    }
                }
            }
            return
        }

        // Background-downloaded file is ready — the file is in the Documents
        // directory but iOS does not allow installing arbitrary IPA files from a
        // file:// path (App Store policy). Notify Flutter so it can prompt the
        // user to open the App Store or an itms-services:// link instead.
        if downloadedFileURL != nil {
            result(FlutterError(
                code: "INSTALL_NOT_SUPPORTED",
                message: "iOS cannot install IPA files directly. Use an itms-services:// URL for enterprise OTA installation.",
                details: nil
            ))
            return
        }

        result(FlutterError(code: "NO_DOWNLOAD", message: "No downloaded update available. Call startFlexibleUpdate first.", details: nil))
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
        // The App Store id is not derivable from the bundle identifier, so we
        // resolve the real store URL via the iTunes lookup before opening it.
        fetchAppStoreURL { urlString in
            DispatchQueue.main.async {
                guard let urlString = urlString, let url = URL(string: urlString) else {
                    result(FlutterError(code: "CANNOT_OPEN_APP_STORE", message: "Cannot resolve App Store URL", details: nil))
                    return
                }

                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url) { success in
                        result(success)
                    }
                } else {
                    result(FlutterError(code: "CANNOT_OPEN_APP_STORE", message: "Cannot open App Store", details: nil))
                }
            }
        }
    }

    /// Resolves the canonical App Store URL for this app via the iTunes lookup.
    private func fetchAppStoreURL(completion: @escaping (String?) -> Void) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = InAppUpdateMePlugin.iTunesLookupURL(bundleId: bundleId) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let appInfo = results.first else {
                completion(nil)
                return
            }
            completion(InAppUpdateMePlugin.appStoreURL(from: appInfo))
        }.resume()
    }

    /// Builds an App Store URL from an iTunes lookup result, preferring the
    /// canonical `trackViewUrl` and falling back to the numeric `trackId`.
    private static func appStoreURL(from appInfo: [String: Any]) -> String? {
        if let trackViewUrl = appInfo["trackViewUrl"] as? String, !trackViewUrl.isEmpty {
            return trackViewUrl
        }
        if let trackId = appInfo["trackId"] as? Int {
            return "https://apps.apple.com/app/id\(trackId)"
        }
        if let trackId = (appInfo["trackId"] as? NSNumber)?.intValue {
            return "https://apps.apple.com/app/id\(trackId)"
        }
        return nil
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
        // Only forward whole-percent changes to avoid flooding the channel.
        guard progress != lastReportedProgress else { return }
        lastReportedProgress = progress

        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onUpdateProgress", arguments: ["progress": progress])
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.channel?.invokeMethod("onUpdateFailed", arguments: ["error": "Download failed: \(error.localizedDescription)"])
            }
        }
    }

    /// Called once the background session has delivered every queued
    /// delegate event after the app was relaunched to handle them. Signals
    /// the OS that it's now safe to reclaim background-launch resources.
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            InAppUpdateMePlugin.backgroundCompletionHandler?()
            InAppUpdateMePlugin.backgroundCompletionHandler = nil
        }
    }
}