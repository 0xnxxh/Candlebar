import ServiceManagement
import XCTest
@testable import Candlebar

@MainActor
final class LoginItemControllerTests: XCTestCase {
    func testEnablingRegistersAndReadsBackSystemStatus() {
        var systemStatus = SMAppService.Status.notRegistered
        var registrations = 0
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: {
                registrations += 1
                systemStatus = .enabled
            },
            unregister: {},
        )

        XCTAssertFalse(controller.isRegistered)
        controller.setEnabled(true)
        XCTAssertEqual(registrations, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertNil(controller.errorMessage)
        controller.setEnabled(true)
        XCTAssertEqual(registrations, 1)
    }

    func testDisablingUnregistersAndReadsBackSystemStatus() {
        var systemStatus = SMAppService.Status.enabled
        var unregistrations = 0
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: {},
            unregister: {
                unregistrations += 1
                systemStatus = .notRegistered
            },
        )

        controller.setEnabled(false)
        XCTAssertFalse(controller.isRegistered)
        XCTAssertEqual(unregistrations, 1)
        controller.setEnabled(false)
        XCTAssertEqual(unregistrations, 1)
    }

    func testApprovalRequiredRemainsPendingAndCanBeCancelled() {
        var systemStatus = SMAppService.Status.notRegistered
        var registrations = 0
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: {
                registrations += 1
                systemStatus = .requiresApproval
            },
            unregister: { systemStatus = .notRegistered },
        )

        controller.setEnabled(true)
        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertTrue(controller.isRegistered)
        controller.setEnabled(true)
        XCTAssertEqual(registrations, 1)
        controller.setEnabled(false)
        XCTAssertEqual(controller.status, .notRegistered)
    }

    func testRefreshReflectsExternalSystemChangesWithoutRegisteringAgain() {
        var systemStatus = SMAppService.Status.enabled
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: { XCTFail("Refresh must not register the app") },
            unregister: { XCTFail("Refresh must not unregister the app") },
        )

        systemStatus = .requiresApproval
        controller.refresh()
        XCTAssertEqual(controller.status, .requiresApproval)
        systemStatus = .notRegistered
        controller.refresh()
        XCTAssertFalse(controller.isRegistered)
    }

    func testFailedRegistrationShowsErrorAndActualStatusThenCanRetry() {
        var systemStatus = SMAppService.Status.notRegistered
        var shouldFail = true
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: {
                if shouldFail {
                    throw NSError(domain: "LoginItemTest", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Registration denied",
                    ])
                }
                systemStatus = .enabled
            },
            unregister: {},
        )

        controller.setEnabled(true)
        XCTAssertFalse(controller.isRegistered)
        XCTAssertEqual(controller.errorMessage, "Registration denied")
        shouldFail = false
        controller.setEnabled(true)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertNil(controller.errorMessage)
    }

    func testFailedUnregistrationDoesNotPretendToBeDisabled() {
        let controller = LoginItemController(
            readStatus: { .enabled },
            register: {},
            unregister: {
                throw NSError(domain: "LoginItemTest", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Unregistration denied",
                ])
            },
        )

        controller.setEnabled(false)
        XCTAssertTrue(controller.isRegistered)
        XCTAssertEqual(controller.errorMessage, "Unregistration denied")
    }

    func testStatusIsRefreshedBeforeChangingRegistration() {
        var systemStatus = SMAppService.Status.notRegistered
        var unregistrations = 0
        let controller = LoginItemController(
            readStatus: { systemStatus },
            register: { XCTFail("Already enabled externally") },
            unregister: {
                unregistrations += 1
                systemStatus = .notRegistered
            },
        )

        systemStatus = .enabled
        controller.setEnabled(false)
        XCTAssertEqual(unregistrations, 1)
        XCTAssertFalse(controller.isRegistered)
    }

    func testMissingServiceIsNotShownAsRegistered() {
        let controller = LoginItemController(
            readStatus: { .notFound },
            register: {},
            unregister: {},
        )

        XCTAssertEqual(controller.status, .notFound)
        XCTAssertFalse(controller.isRegistered)
    }
}
