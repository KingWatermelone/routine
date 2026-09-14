import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow, UNUserNotificationCenterDelegate {
  private var reminderChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureReminderChannel(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    UNUserNotificationCenter.current().delegate = self

    super.awakeFromNib()
  }

  private func configureReminderChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "routine/reminders",
      binaryMessenger: binaryMessenger
    )
    reminderChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openSettings":
        Self.openNotificationSettings(result: result)
      case "synchronize":
        guard
          let arguments = call.arguments as? [String: Any],
          let values = arguments["reminders"] as? [[String: Any]],
          let requestPermission = arguments["requestPermission"] as? Bool
        else {
          result(
            FlutterError(
              code: "arguments",
              message: "Invalid reminders",
              details: nil
            )
          )
          return
        }

        do {
          let reminders = try values.map { try NativeReminder($0) }
          ReminderBridge.synchronize(
            reminders,
            requestPermission: requestPermission,
            result: result
          )
        } catch {
          result(
            FlutterError(
              code: "arguments",
              message: "Invalid reminder",
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func openNotificationSettings(result: FlutterResult) {
    let notificationSettingsURL: URL?
    if #available(macOS 13.0, *) {
      notificationSettingsURL = URL(
        string:
          "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
      )
    } else {
      notificationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.notifications"
      )
    }

    if let url = notificationSettingsURL, NSWorkspace.shared.open(url) {
      result(nil)
      return
    }

    if
      let systemSettingsURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "com.apple.systempreferences"
      ),
      NSWorkspace.shared.open(systemSettingsURL)
    {
      result(nil)
      return
    }

    result(
      FlutterError(
        code: "settings",
        message: "Notification settings unavailable",
        details: nil
      )
    )
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("routine.") {
      completionHandler([.banner, .sound, .list])
    } else {
      completionHandler([])
    }
  }
}

// Kept in an existing compiled source file so the Xcode target needs no new file references.
struct NativeReminder {
  let id: String
  let title: String
  let date: Date

  init(_ value: [String: Any]) throws {
    guard
      let id = value["id"] as? String,
      id.hasPrefix("routine."),
      let title = value["title"] as? String,
      !title.isEmpty,
      let time = value["time"] as? NSNumber,
      time.doubleValue.isFinite
    else {
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

    // Store an absolute instant so a later time-zone change does not move it.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: date
    )
    components.timeZone = calendar.timeZone

    return UNNotificationRequest(
      identifier: id,
      content: content,
      trigger: UNCalendarNotificationTrigger(
        dateMatching: components,
        repeats: false
      )
    )
  }
}

enum ReminderBridge {
  static func synchronize(
    _ reminders: [NativeReminder],
    requestPermission: Bool,
    result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      if
        settings.authorizationStatus == .notDetermined,
        requestPermission,
        !reminders.isEmpty
      {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
          if let error = error {
            DispatchQueue.main.async {
              result(
                FlutterError(
                  code: "permission",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          } else {
            synchronize(
              reminders,
              requestPermission: false,
              result: result
            )
          }
        }
        return
      }

      let allowed =
        settings.authorizationStatus == .authorized
        || settings.authorizationStatus == .provisional

      center.getPendingNotificationRequests { pending in
        DispatchQueue.main.async {
          let future = reminders
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }

          // Reserve space for notifications owned by future organizer modules.
          let foreignCount = pending.filter {
            !$0.identifier.hasPrefix("routine.")
          }.count
          let capacity = max(0, 64 - foreignCount)
          let desired = allowed ? Array(future.prefix(capacity)) : []
          let desiredIdentifiers = Set(desired.map { $0.id })
          let obsoleteIdentifiers = pending
            .filter {
              $0.identifier.hasPrefix("routine.")
                && !desiredIdentifiers.contains($0.identifier)
            }
            .map { $0.identifier }

          center.removePendingNotificationRequests(
            withIdentifiers: obsoleteIdentifiers
          )

          var warning: String?
          if !future.isEmpty && !allowed {
            warning =
              "Mitteilungen sind nicht erlaubt. Aktiviere sie unter Systemeinstellungen → Mitteilungen → Routine."
          } else if future.count > capacity {
            warning =
              "Nur die nächsten \(capacity) Erinnerungen sind geplant. Öffne die App erneut, um spätere Erinnerungen nachzuplanen."
          } else if
            !future.isEmpty
              && (settings.alertSetting != .enabled
                || settings.soundSetting != .enabled)
          {
            warning =
              "Banner oder Töne sind deaktiviert. Prüfe die Mitteilungseinstellungen für Routine."
          }

          func addNext(_ index: Int) {
            guard index < desired.count else {
              result(warning)
              return
            }

            let reminder = desired[index]
            if reminder.date <= Date() {
              addNext(index + 1)
              return
            }

            center.add(reminder.notificationRequest) { error in
              DispatchQueue.main.async {
                if let error = error {
                  result(
                    FlutterError(
                      code: "schedule",
                      message: error.localizedDescription,
                      details: nil
                    )
                  )
                } else {
                  addNext(index + 1)
                }
              }
            }
          }

          addNext(0)
        }
      }
    }
  }
}
