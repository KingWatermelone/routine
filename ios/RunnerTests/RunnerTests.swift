import Flutter
import UIKit
import XCTest
import UserNotifications
@testable import Runner

class RunnerTests: XCTestCase {

  func testReminderUsesStableIdentifierAndAbsoluteUTCDate() throws {
    let reminder = try NativeReminder(["id": "routine.task.1", "title": "Practice", "time": 1800000000000 as Int64])
    let request = reminder.notificationRequest
    XCTAssertEqual(request.identifier, "routine.task.1")
    XCTAssertEqual(request.content.title, "Practice")
    XCTAssertFalse(request.trigger!.repeats)
    let trigger = request.trigger as! UNCalendarNotificationTrigger
    XCTAssertEqual(trigger.dateComponents.timeZone, TimeZone(secondsFromGMT: 0))
    XCTAssertEqual(Calendar(identifier: .gregorian).date(from: trigger.dateComponents), reminder.date)
  }

  func testInvalidReminderIsRejected() {
    XCTAssertThrowsError(try NativeReminder(["id": "foreign", "title": "Test", "time": 123]))
    XCTAssertThrowsError(try NativeReminder(["id": "routine.a", "time": 123]))
  }

}
