//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension TimeInterval {
    var description: String {
        var value = 0
        var unit = Units.second
        Units.allCases.forEach { u in
            if self.rounded() >= u.rawValue {
                value = Int((self / u.rawValue).rounded())
                unit = u
            }
        }
        return "\(value) \(unit.description)\(value > 1 ? "s" : "")"
    }

    enum Units: Double, CaseIterable {
        case second = 1
        case minute = 60
        case hour = 3600
        case day = 86400
        case week = 604800

        var description: String {
            switch self {
            case .second: return "Second"
            case .minute: return "Minute"
            case .hour: return "Hour"
            case .day: return "Day"
            case .week: return "Week"
            }
        }
    }
}
