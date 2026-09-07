import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var reminderChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "routine/reminders",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    reminderChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(FlutterError(code: "settings", message: "Settings unavailable", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success ? nil : FlutterError(code: "settings", message: "Settings unavailable", details: nil))
        }
      case "synchronize":
        guard let args = call.arguments as? [String: Any],
          let values = args["reminders"] as? [[String: Any]],
          let request = args["requestPermission"] as? Bool else {
          result(FlutterError(code: "arguments", message: "Invalid reminders", details: nil))
          return
        }
        do {
          let reminders = try values.map { try NativeReminder($0) }
          ReminderBridge.synchronize(reminders, requestPermission: request, result: result)
        } catch {
          result(FlutterError(code: "arguments", message: "Invalid reminder", details: nil))
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.identifier.hasPrefix("routine.") {
      if #available(iOS 14.0, *) { completionHandler([.banner, .sound, .list]) }
      else { completionHandler([.alert, .sound]) }
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }
}

// Kept in the existing compiled source file so the Xcode target needs no new file references.
struct NativeReminder {
  let id: String
  let title: String
  let date: Date
  init(_ value: [String: Any]) throws {
    guard let id = value["id"] as? String, id.hasPrefix("routine."),
      let title = value["title"] as? String, !title.isEmpty,
      let time = value["time"] as? NSNumber, time.doubleValue.isFinite else {
      throw NSError(domain: "routine.reminders", code: 1)
    }
    self.id = id
    self.title = title
    self.date = Date(timeIntervalSince1970: time.doubleValue / 1000)
  }

  var notificationRequest: UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = "Erinnerung an deine Aufgabe"
    content.sound = .default
    // An absolute instant: changing device time zone does not move the reminder.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    components.timeZone = calendar.timeZone
    return UNNotificationRequest(identifier: id, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
  }
}

enum ReminderBridge {
  static func synchronize(_ reminders: [NativeReminder], requestPermission: Bool,
    result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      if settings.authorizationStatus == .notDetermined && requestPermission && !reminders.isEmpty {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
          if let error = error {
            DispatchQueue.main.async { result(FlutterError(code: "permission", message: error.localizedDescription, details: nil)) }
          } else {
            synchronize(reminders, requestPermission: false, result: result)
          }
        }
        return
      }
      let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      center.getPendingNotificationRequests { pending in
        DispatchQueue.main.async {
          let future = reminders.filter { $0.date > Date() }.sorted { $0.date < $1.date }
          // Reserve space for any future modules' notifications; never delete their requests.
          let capacity = max(0, 64 - pending.filter { !$0.identifier.hasPrefix("routine.") }.count)
          let desired = allowed ? Array(future.prefix(capacity)) : []
          let ids = Set(desired.map { $0.id })
          let obsolete = pending.filter { $0.identifier.hasPrefix("routine.") && !ids.contains($0.identifier) }.map { $0.identifier }
          center.removePendingNotificationRequests(withIdentifiers: obsolete)
          var warning: String?
          if !future.isEmpty && !allowed {
            warning = "Mitteilungen sind nicht erlaubt. Aktiviere sie unter Einstellungen → Mitteilungen → Routine."
          } else if future.count > capacity {
            warning = "Nur die nächsten \(capacity) Erinnerungen sind geplant. Öffne die App erneut, um spätere Erinnerungen nachzuplanen."
          } else if !future.isEmpty && (settings.alertSetting != .enabled || settings.soundSetting != .enabled) {
            warning = "Banner oder Töne sind deaktiviert. Prüfe die Mitteilungseinstellungen für Routine."
          }
          // Add sequentially; report platform failures instead of claiming successful delivery.
          func addNext(_ index: Int) {
            guard index < desired.count else { result(warning); return }
            let reminder = desired[index]
            if reminder.date <= Date() { addNext(index + 1); return }
            center.add(reminder.notificationRequest) { error in
              DispatchQueue.main.async {
                if let error = error {
                  result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil))
                } else { addNext(index + 1) }
              }
            }
          }
          addNext(0)
        }
      }
    }
  }
}
