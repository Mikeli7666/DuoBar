import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let status: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    private let openLoginSettings: () -> Void

    init(
        status: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() },
        openLoginSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        self.status = status
        self.register = register
        self.unregister = unregister
        self.openLoginSettings = openLoginSettings
        refresh()
    }

    func refresh() {
        let status = status()
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func repairRegistration() {
        errorMessage = nil
        do {
            if status() != .notRegistered {
                try unregister()
            }
            try register()
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                if status() == .requiresApproval {
                    openLoginSettings()
                } else if status() != .enabled {
                    try register()
                }
            } else {
                try unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }
}
