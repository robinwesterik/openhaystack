//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension UserDefaults {
    var urlString: String? {
        get {
            return self.string(forKey: "serverURLString")
        }
        set(v) {
            self.set(v, forKey: "serverURLString")
            self.synchronize()
        }
    }
}
