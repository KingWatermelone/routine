import Cocoa
import FlutterMacOS
import UserNotifications
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testReminderUsesStableIdentifierAndAbsoluteUTCDate() throws {
    let reminder = try NativeReminder([
      "id": "routine.task.1",
      "title": "Practice",
      "time": 1_800_000_000_000 as Int64,
    ])

    let request = reminder.notificationRequest
    XCTAssertEqual(request.identifier, "routine.task.1")
    XCTAssertEqual(request.content.title, "Practice")
    XCTAssertEqual(request.content.body, "Erinnerung an deine Aufgabe")
    XCTAssertFalse(request.trigger!.repeats)

    let trigger = try XCTUnwrap(
      request.trigger as? UNCalendarNotificationTrigger
    )
    XCTAssertEqual(
      trigger.dateComponents.timeZone,
      TimeZone(secondsFromGMT: 0)
    )
    XCTAssertEqual(
      Calendar(identifier: .gregorian).date(
        from: trigger.dateComponents
      ),
      reminder.date
    )
  }

  func testInvalidReminderIsRejected() {
    XCTAssertThrowsError(
      try NativeReminder([
        "id": "foreign",
        "title": "Test",
        "time": 123,
      ])
    )
    XCTAssertThrowsError(
      try NativeReminder([
        "id": "routine.a",
        "time": 123,
      ])
    )
    XCTAssertThrowsError(
      try NativeReminder([
        "id": "routine.a",
        "title": "",
        "time": 123,
      ])
    )
  }
}
