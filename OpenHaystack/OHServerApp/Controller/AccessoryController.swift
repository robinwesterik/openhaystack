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

class AccessoryController: ObservableObject {
    @Published var accessories: [Accessory]
    var selfObserver: AnyCancellable?
    var listElementsObserver = [AnyCancellable]()

    init(accessories: [Accessory]) {
        self.accessories = accessories
        initAccessoryObserver()
        initObserver()
    }

    convenience init() {
        self.init(accessories: KeychainController.loadAccessoriesFromKeychain())
    }

    func initAccessoryObserver() {
        self.selfObserver = self.objectWillChange.sink { _ in
            // objectWillChange is called before the values are actually changed,
            // so we dispatch the call to save()
            DispatchQueue.main.async {
                self.initObserver()
                try? self.save()
            }
        }
    }

    func initObserver() {
        self.listElementsObserver.forEach({
            $0.cancel()
        })
        self.accessories.forEach({
            let c = $0.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
            // Important: You have to keep the returned value allocated,
            // otherwise the sink subscription gets cancelled
            self.listElementsObserver.append(c)
        })
    }

    func save() throws {
        try KeychainController.storeInKeychain(accessories: self.accessories)
    }

    func delete(accessory: Accessory) throws {
        var accessories = self.accessories
        guard let idx = accessories.firstIndex(of: accessory) else { return }

        accessories.remove(at: idx)

        withAnimation {
            self.accessories = accessories
        }
    }

    func addAccessory() throws -> Accessory {
        let accessory = try Accessory()
        self.accessories.append(accessory)
        return accessory
    }

    #if os(macOS)
        /// Export the accessories property list so it can be imported at another location.
        func export(accessories: [Accessory]) throws -> URL {
            let propertyList = try PropertyListEncoder().encode(accessories)

            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["plist"]
            savePanel.canCreateDirectories = true
            savePanel.directoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            savePanel.message = "This export contains all private keys! Keep the file save to protect your location data"
            savePanel.nameFieldLabel = "Filename"
            savePanel.nameFieldStringValue = "openhaystack_accessories.plist"
            savePanel.prompt = "Export"
            savePanel.title = "Export accessories & keys"

            let result = savePanel.runModal()

            if result == .OK,
                let url = savePanel.url
            {
                // Store the accessory file
                try propertyList.write(to: url)

                return url
            }
            throw ImportError.cancelled
        }



        enum ImportError: Error {
            case cancelled
        }


    #endif

}

class AccessoryControllerPreview: AccessoryController {
    override func save() {
        // don't allow saving dummy data to keychain
    }
}
