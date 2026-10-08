import Combine
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    init(
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() },
    ) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        status = readStatus()
    }

    // Pending approval is registered, but is not eligible to launch yet.
    var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    func refresh() {
        status = readStatus()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        refresh()
        guard enabled != isRegistered else { return }

        do {
            if enabled {
                try register()
            } else {
                try unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
