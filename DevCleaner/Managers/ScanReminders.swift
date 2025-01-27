//
//  ScanReminders.swift
//  DevCleaner
//
//  Created by Konrad Kołakowski on 11.05.2018.
//  Copyright © 2018 One Minute Games. All rights reserved.
//
//  DevCleaner is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  DevCleaner is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with DevCleaner.  If not, see <http://www.gnu.org/licenses/>.

import Cocoa
import Foundation
import UserNotifications

public final class ScanReminders {
    // MARK: Types
    public enum Period: Int {
        case everyWeek, every2weeks, everyMonth, every2Months

        private var dateComponents: DateComponents {
            var result = DateComponents()

            switch self {
            case .everyWeek:
                result.day = 7
            case .every2weeks:
                result.day = 7 * 2
            case .everyMonth:
                result.month = 1
            case .every2Months:
                result.month = 2
            }

            return result
        }

        internal var repeatInterval: DateComponents {
            var result = DateComponents()

            #if DEBUG
                if Preferences.shared.envKeyPresent(key: "DCNotificationsTest") {
                    result.day = 1  // for debug we change our periods to one day
                } else {
                    result = self.dateComponents
                }
            #else
                result = self.dateComponents
            #endif

            return result
        }
    }

    // MARK: Properties
    public static var dateOfNextReminder: Date? {
        let center = UNUserNotificationCenter.current()
        var result: Date?

        let semaphore = DispatchSemaphore(value: 0)
        center.getPendingNotificationRequests { requests in
            if let firstRequest = requests.first(where: { $0.identifier == self.reminderIdentifier }
            ),
                let nextTriggerDate = (firstRequest.trigger as? UNCalendarNotificationTrigger)?
                    .nextTriggerDate()
            {
                result = nextTriggerDate
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)

        return result
    }

    // MARK: Constants
    private static let reminderIdentifier = "com.oneminutegames.DevCleaner.scanReminder"

    // MARK: Manage reminders
    public static func scheduleReminder(period: Period) {
        let center = UNUserNotificationCenter.current()

        // Request authorization
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { return }

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Scan Xcode cache?"
            content.body =
                "It's been a while since your last scan, check if you can reclaim some storage."
            content.sound = .default

            // Calculate next notification date
            let calendar = Calendar.current
            if let initialDeliveryDate = calendar.date(byAdding: period.repeatInterval, to: Date())
            {
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: initialDeliveryDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

                // Create request
                let request = UNNotificationRequest(
                    identifier: reminderIdentifier,
                    content: content,
                    trigger: trigger)

                // Schedule notification
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            }
        }
    }

    public static func disableReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
