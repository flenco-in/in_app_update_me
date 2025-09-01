import Flutter
import UIKit
import Foundation

public class InAppUpdateMePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "in_app_update_me", binaryMessenger: registrar.messenger())
        let instance = InAppUpdateMePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
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
                    "appStoreUrl": "https://apps.apple.com/app/id\(appInfo["trackId"] as? Int64 ?? 0)"
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
                    "currentVersion": currentVersion
                ])
            }
        }.resume()
    }
    
    private func startFlexibleUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't support flexible updates like Android
        // We'll redirect to App Store for updates
        redirectToAppStore(result: result)
    }
    
    private func startImmediateUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't support immediate updates like Android
        // We'll redirect to App Store for updates
        redirectToAppStore(result: result)
    }
    
    private func completeFlexibleUpdate(result: @escaping FlutterResult) {
        // iOS doesn't support flexible updates
        result(FlutterError(code: "NOT_SUPPORTED", message: "Flexible updates not supported on iOS", details: nil))
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
}