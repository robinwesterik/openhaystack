//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation
import OSLog
import SwiftUI

class FindMyController: ObservableObject {
    @Published var error: Error?
    @Published var devices = [FindMyDevice]()

    /// If we use an intermediate server for fetching reports its URL has to be stored here
    var serverURL: URL?

    func loadPrivateKeys(from data: Data, with searchPartyToken: Data, completion: @escaping (Error?) -> Void) {
        do {
            let devices = try PropertyListDecoder().decode([FindMyDevice].self, from: data)

            self.devices.append(contentsOf: devices)
            self.fetchReports(with: searchPartyToken, completion: completion)
        } catch {
            self.error = FindMyErrors.decodingPlistFailed(message: String(describing: error))
        }
    }

    func importReports(reports: [FindMyReport], and keys: Data, completion: @escaping () -> Void) throws {
        let devices = try PropertyListDecoder().decode([FindMyDevice].self, from: keys)
        self.devices = devices

        // Decrypt the reports with the imported keys
        DispatchQueue.global(qos: .background).async {

            var d = self.devices
            // Add the reports to the according device by finding the right key for the report
            for report in reports {
                let dI = d.firstIndex { (device) -> Bool in
                    device.keys.contains { (key) -> Bool in
                        key.hashedKey.base64EncodedString() == report.id
                    }
                }

                guard let deviceIndex = dI else {
                    print("No device found for id")
                    continue
                }

                if var reports = d[deviceIndex].reports {
                    reports.append(report)
                    d[deviceIndex].reports = reports
                } else {
                    d[deviceIndex].reports = [report]
                }
            }

            // Decrypt the reports
            self.decryptReports {
                self.exportDevices()
                DispatchQueue.main.async {
                    completion()
                }
            }

        }
    }

    func importDevices(devices: Data) throws {
        var devices = try PropertyListDecoder().decode([FindMyDevice].self, from: devices)

        // Delete the decrypted reports
        for idx in devices.startIndex..<devices.endIndex {
            devices[idx].decryptedReports = nil
        }

        self.devices = devices

        // Decrypt reports again with additional information
        self.decryptReports {

        }
    }

    func fetchReports(for accessories: [Accessory], with token: Data, completion: @escaping (Result<[FindMyDevice], Error>) -> Void) {
        let findMyDevices = accessories.compactMap({ acc -> FindMyDevice? in
            do {
                return try acc.toFindMyDevice()
            } catch {
                os_log("Failed getting id for key %@", String(describing: error))
                return nil
            }
        })

        self.devices = findMyDevices

        self.fetchReports(with: token) { error in

            if let error = error {
                completion(.failure(error))
                os_log("Error: %@", String(describing: error))
            } else {
                completion(.success(self.devices))
            }
        }
    }

    func decryptReports(completion: () -> Void) {
        print("Decrypting reports")

        // Iterate over all devices
        for deviceIdx in 0..<devices.count {
            devices[deviceIdx].decryptedReports = []
            let device = devices[deviceIdx]

            // Map the keys in a dictionary for faster access
            guard let reports = device.reports else { continue }
            let keyMap = device.keys.reduce(into: [String: FindMyKey](), { $0[$1.hashedKey.base64EncodedString()] = $1 })

            let accessQueue = DispatchQueue(label: "threadSafeAccess", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
            var decryptedReports = [FindMyLocationReport](repeating: FindMyLocationReport(lat: 0, lng: 0, acc: 0, dP: Date(), t: Date(), c: 0), count: reports.count)
            DispatchQueue.concurrentPerform(iterations: reports.count) { (reportIdx) in
                let report = reports[reportIdx]
                guard let key = keyMap[report.id] else { return }
                do {
                    // Decrypt the report
                    let locationReport = try DecryptReports.decrypt(report: report, with: key)
                    accessQueue.async(flags: .barrier) {
                        decryptedReports[reportIdx] = locationReport
                    }
                } catch {
                    return
                }
            }

            accessQueue.sync {
                devices[deviceIdx].decryptedReports = decryptedReports
            }
        }

        completion()

    }

    func exportDevices() {

        if let encoded = try? PropertyListEncoder().encode(self.devices) {
            let outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            try? encoded.write(to: outputDirectory.appendingPathComponent("devices-\(Date()).plist"))
        }
    }

}

enum FindMyErrors: Error {
    case decodingPlistFailed(message: String)
    case noServerURL
    case serverError(message: String)
}
