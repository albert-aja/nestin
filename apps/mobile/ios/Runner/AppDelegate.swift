import Flutter
import UIKit
import CoreLocation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var geofenceManager: GeofenceManager?
  private var deviceControlManager: DeviceControlManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeofenceManager.restoreBackgroundMonitoringIfNeeded()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.nestin.app/geofencing",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    geofenceManager = GeofenceManager(channel: channel)
    let deviceControlChannel = FlutterMethodChannel(
      name: "com.nestin.app/device_control",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    deviceControlManager = DeviceControlManager(channel: deviceControlChannel)
  }
}

/// Honest iOS platform capability bridge for Nestin Scout Digital Wellbeing & Phone Modes.
/// Never fakes cross-app Screen Time or system DND when Apple FamilyControls entitlements are absent.
final class DeviceControlManager: NSObject {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    self.channel.setMethodCallHandler(handle)
  }

  private func hasFamilyControlsEntitlement() -> Bool {
    if let value = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.family-controls") as? Bool {
      return value
    }
    return false
  }

  private func openAppSettings() -> Bool {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
    DispatchQueue.main.async {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let hasFamilyControls = hasFamilyControlsEntitlement()
    switch call.method {
    case "inspectCapabilities":
      let screenBrightness = Int(round(UIScreen.main.brightness * 100.0))
      let locationStatus = CLLocationManager().authorizationStatus
      let hasLocation = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
      let hasAlwaysLocation = locationStatus == .authorizedAlways
      result([
        "platform": "ios",
        "manufacturer": "Apple",
        "brand": "Apple",
        "model": UIDevice.current.model,
        "osVersion": UIDevice.current.systemVersion,
        "sdkInt": 0,
        "brightnessRaw": screenBrightness,
        "dndFilter": 1,
        "screenTimeoutMs": 30000,
        "hasUsageStats": hasFamilyControls,
        "hasDndAccess": false,
        "canWriteSettings": false,
        "hasOverlayPermission": false,
        "hasAccessibilityService": false,
        "hasExactAlarm": true,
        "hasNotifications": true,
        "hasLocation": hasLocation,
        "hasBackgroundLocation": hasAlwaysLocation,
        "isBatteryOptimizationExempt": true,
        "hasFamilyControlsEntitlement": hasFamilyControls
      ])
    case "readSystemState":
      let screenBrightness = Int(round(UIScreen.main.brightness * 100.0))
      result([
        "dndFilter": 1,
        "brightnessRaw": screenBrightness,
        "screenTimeoutMs": 30000,
        "hasUsageStats": hasFamilyControls,
        "hasDndAccess": false,
        "canWriteSettings": false,
        "hasOverlayPermission": false,
        "hasAccessibilityService": false,
        "hasExactAlarm": true,
        "hasNotifications": true,
        "isBatteryOptimizationExempt": true,
        "hasFamilyControlsEntitlement": hasFamilyControls
      ])
    case "getAppUsageToday":
      result([
        "permissionGranted": false,
        "boundaryMessage": hasFamilyControls
          ? "DeviceActivity report extension setup required in Apple Screen Time."
          : "Cross-app Screen Time telemetry on iOS requires Apple FamilyControls entitlement; reporting unavailable honestly.",
        "records": []
      ])
    case "setDndEnabled", "restoreDndFilter":
      result([
        "support": "delegatedToSystemSettings",
        "succeeded": false,
        "message": "iOS does not permit third-party apps to toggle global Focus/DND directly; use iOS Focus Settings."
      ])
    case "setScreenBrightness", "restoreBrightness":
      result([
        "support": "unsupported",
        "succeeded": false,
        "message": "iOS does not support persistent system-wide screen brightness control outside the active app session."
      ])
    case "setScreenTimeoutSeconds", "restoreScreenTimeoutMs":
      result([
        "support": "unsupported",
        "succeeded": false,
        "message": "iOS restricts system Auto-Lock duration to iOS Display & Brightness settings."
      ])
    case "openPermissionSettings", "openSystemModesOrWellbeing":
      result(openAppSettings())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class GeofenceManager: NSObject, CLLocationManagerDelegate {
  private static let regionsDefaultsKey = "nestin_geofence_regions_v1"
  private static let pendingDefaultsKey = "nestin_geofence_pending_events_v1"
  private static let regionPrefix = "nestin_geo_"
  private static var sharedBackgroundManager: GeofenceManager?

  private let locationManager = CLLocationManager()
  private var channel: FlutterMethodChannel?
  private var pendingPermissionResult: FlutterResult?
  private var pendingLocationResult: FlutterResult?

  static func restoreBackgroundMonitoringIfNeeded() {
    if sharedBackgroundManager == nil {
      sharedBackgroundManager = GeofenceManager(channel: nil)
    }
  }

  init(channel: FlutterMethodChannel?) {
    self.channel = channel
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.pausesLocationUpdatesAutomatically = true

    if let channel = channel {
      GeofenceManager.sharedBackgroundManager = self
      bind(channel: channel)
    }
  }

  private func bind(channel: FlutterMethodChannel) {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: nil, details: nil))
        return
      }
      switch call.method {
      case "isSupported":
        result(CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self))
      case "checkPermission":
        result(self.currentPermissionString())
      case "requestForegroundPermission":
        self.requestForeground(result: result)
      case "requestBackgroundPermission":
        self.requestBackground(result: result)
      case "openAppLocationSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { ok in
              result(ok)
            }
          }
        } else {
          result(false)
        }
      case "getCurrentLocation":
        self.fetchCurrentLocation(result: result)
      case "syncGeofences":
        let args = call.arguments as? [String: Any]
        let regions = args?["regions"] as? [[String: Any]] ?? []
        result(self.syncGeofences(regions: regions))
      case "removeGeofence":
        let args = call.arguments as? [String: Any]
        if let id = args?["id"] as? String {
          self.removeRegion(id: id)
          result(true)
        } else {
          result(false)
        }
      case "clearAllGeofences":
        self.clearAllRegions()
        result(true)
      case "drainPendingEvents":
        result(self.drainPendingEvents())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func authorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    } else {
      return CLLocationManager.authorizationStatus()
    }
  }

  private func currentPermissionString() -> String {
    switch authorizationStatus() {
    case .authorizedAlways:
      return "always"
    case .authorizedWhenInUse:
      return "whileInUse"
    case .denied, .restricted:
      return "deniedForever"
    case .notDetermined:
      return "denied"
    @unknown default:
      return "denied"
    }
  }

  private func requestForeground(result: @escaping FlutterResult) {
    let status = authorizationStatus()
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      result(currentPermissionString())
      return
    }
    pendingPermissionResult = result
    locationManager.requestWhenInUseAuthorization()
  }

  private func requestBackground(result: @escaping FlutterResult) {
    let status = authorizationStatus()
    if status == .authorizedAlways {
      result("always")
      return
    }
    pendingPermissionResult = result
    if status == .notDetermined {
      locationManager.requestWhenInUseAuthorization()
    } else {
      locationManager.requestAlwaysAuthorization()
    }
  }

  private func fetchCurrentLocation(result: @escaping FlutterResult) {
    if let last = locationManager.location,
       abs(last.timestamp.timeIntervalSinceNow) < 120 {
      result(locationDictionary(last))
      return
    }
    pendingLocationResult = result
    locationManager.requestLocation()
  }

  private func locationDictionary(_ loc: CLLocation) -> [String: Any] {
    return [
      "latitude": loc.coordinate.latitude,
      "longitude": loc.coordinate.longitude,
      "accuracy": loc.horizontalAccuracy,
      "timestampMs": Int64(loc.timestamp.timeIntervalSince1970 * 1000.0),
      "isSimulated": false
    ]
  }

  private func syncGeofences(regions: [[String: Any]]) -> Bool {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      return false
    }

    for region in locationManager.monitoredRegions {
      if region.identifier.hasPrefix(GeofenceManager.regionPrefix) {
        locationManager.stopMonitoring(for: region)
      }
    }

    let capped = Array(regions.prefix(20))
    UserDefaults.standard.set(capped, forKey: GeofenceManager.regionsDefaultsKey)

    for reg in capped {
      guard let id = reg["id"] as? String,
            let lat = reg["latitude"] as? Double,
            let lng = reg["longitude"] as? Double else { continue }
      let radiusRaw = reg["radiusMeters"] as? Double ?? 150.0
      let clampedRadius = min(max(radiusRaw, 50.0), locationManager.maximumRegionMonitoringDistance)
      let triggerType = reg["triggerType"] as? String ?? "arrive"

      let circular = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        radius: clampedRadius,
        identifier: "\(GeofenceManager.regionPrefix)\(id)"
      )
      circular.notifyOnEntry = (triggerType == "arrive" || triggerType == "both")
      circular.notifyOnExit = (triggerType == "leave" || triggerType == "both")
      locationManager.startMonitoring(for: circular)
    }

    return true
  }

  private func removeRegion(id: String) {
    let targetIdentifier = "\(GeofenceManager.regionPrefix)\(id)"
    for region in locationManager.monitoredRegions where region.identifier == targetIdentifier {
      locationManager.stopMonitoring(for: region)
    }
    var saved = UserDefaults.standard.array(forKey: GeofenceManager.regionsDefaultsKey) as? [[String: Any]] ?? []
    saved.removeAll { ($0["id"] as? String) == id }
    UserDefaults.standard.set(saved, forKey: GeofenceManager.regionsDefaultsKey)
  }

  private func clearAllRegions() {
    for region in locationManager.monitoredRegions where region.identifier.hasPrefix(GeofenceManager.regionPrefix) {
      locationManager.stopMonitoring(for: region)
    }
    UserDefaults.standard.removeObject(forKey: GeofenceManager.regionsDefaultsKey)
  }

  private func handleRegionTransition(region: CLRegion, isEntering: Bool) {
    guard region.identifier.hasPrefix(GeofenceManager.regionPrefix) else { return }
    let id = String(region.identifier.dropFirst(GeofenceManager.regionPrefix.count))
    var saved = UserDefaults.standard.array(forKey: GeofenceManager.regionsDefaultsKey) as? [[String: Any]] ?? []
    guard let idx = saved.firstIndex(where: { ($0["id"] as? String) == id }) else { return }

    var entry = saved[idx]
    let triggerType = entry["triggerType"] as? String ?? "arrive"
    let matches = (triggerType == "both") || (triggerType == "arrive" && isEntering) || (triggerType == "leave" && !isEntering)
    guard matches else { return }

    let nowMs = Int64(Date().timeIntervalSince1970 * 1000.0)
    let cooldownMins = (entry["cooldownMinutes"] as? Int) ?? 30
    let lastTriggeredMs = (entry["lastTriggeredMs"] as? Int64) ?? 0
    if lastTriggeredMs > 0 && cooldownMins > 0 && ((nowMs - lastTriggeredMs) / 60000) < Int64(cooldownMins) {
      return
    }

    entry["lastTriggeredMs"] = nowMs
    let oneTimeOnly = (entry["oneTimeOnly"] as? Bool) ?? false
    if oneTimeOnly {
      locationManager.stopMonitoring(for: region)
      saved.remove(at: idx)
    } else {
      saved[idx] = entry
    }
    UserDefaults.standard.set(saved, forKey: GeofenceManager.regionsDefaultsKey)

    let placeId = entry["placeId"] as? String ?? ""
    let placeName = entry["placeName"] as? String ?? "Saved Place"
    let title = entry["title"] as? String ?? "Location Reminder"
    let notes = entry["notes"] as? String ?? ""

    postLocalNotification(reminderId: id, title: title, notes: notes, placeName: placeName, isEntering: isEntering)

    let payload: [String: Any] = [
      "reminderId": id,
      "placeId": placeId,
      "placeName": placeName,
      "transition": isEntering ? "enter" : "exit",
      "timestampMs": nowMs,
      "latitude": (entry["latitude"] as? Double) ?? 0.0,
      "longitude": (entry["longitude"] as? Double) ?? 0.0,
      "isSimulated": false,
      "alreadyNotifiedNatively": true
    ]

    if let channel = channel {
      DispatchQueue.main.async {
        channel.invokeMethod("onGeofenceTransition", arguments: payload)
      }
    } else {
      var queued = UserDefaults.standard.array(forKey: GeofenceManager.pendingDefaultsKey) as? [[String: Any]] ?? []
      queued.append(payload)
      UserDefaults.standard.set(queued, forKey: GeofenceManager.pendingDefaultsKey)
    }
  }

  private func postLocalNotification(
    reminderId: String,
    title: String,
    notes: String,
    placeName: String,
    isEntering: Bool
  ) {
    let content = UNMutableNotificationContent()
    let prefix = isEntering ? "Near \(placeName)" : "Leaving \(placeName)"
    content.title = "🧭 \(prefix): \(title)"
    content.body = notes.isEmpty
      ? (isEntering ? "Arriving near \(placeName)" : "Departing \(placeName)")
      : notes
    content.sound = .default

    let req = UNNotificationRequest(
      identifier: "nestin_geo_\(reminderId)_\(Int(Date().timeIntervalSince1970))",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
  }

  private func drainPendingEvents() -> [[String: Any]] {
    let pending = UserDefaults.standard.array(forKey: GeofenceManager.pendingDefaultsKey) as? [[String: Any]] ?? []
    UserDefaults.standard.removeObject(forKey: GeofenceManager.pendingDefaultsKey)
    return pending
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    handleRegionTransition(region: region, isEntering: true)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    handleRegionTransition(region: region, isEntering: false)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if let callback = pendingPermissionResult {
      pendingPermissionResult = nil
      callback(currentPermissionString())
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if let callback = pendingPermissionResult {
      pendingPermissionResult = nil
      callback(currentPermissionString())
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let callback = pendingLocationResult {
      pendingLocationResult = nil
      if let loc = locations.last {
        callback(locationDictionary(loc))
      } else {
        callback(nil)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let callback = pendingLocationResult {
      pendingLocationResult = nil
      callback(nil)
    }
  }
}
