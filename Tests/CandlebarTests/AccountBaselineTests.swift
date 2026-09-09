import Foundation
import XCTest
@testable import Candlebar

final class AccountBaselineTests: XCTestCase {
    private let midnight: Int64 = 1_782_864_000_000

    func testMiddayLaunchTracksChangesFromFirstSuccessfulObservation() throws {
        try withStore { store, _ in
            let first = try XCTUnwrap(store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight + 3_600_000))
            XCTAssertEqual(first.change(current: wallets(100, 200))?.amount, 0)
            let second = try XCTUnwrap(store.baseline(wallets: wallets(110, 200), apiKey: "a", now: midnight + 7_200_000))
            XCTAssertEqual(second.sampledAt, first.sampledAt)
            XCTAssertEqual(second.change(current: wallets(110, 200))?.amount, 10)
            XCTAssertEqual(second.basis, .observation)
        }
    }

    func testChangeUsesLatestValueAndIncludesDepositsWithOneSharedBaseline() throws {
        try withStore { store, _ in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight + 20_000)
            let current = wallets(150, 210)
            let baseline = try XCTUnwrap(store.baseline(wallets: current, apiKey: "a", now: midnight + 3_600_000))
            let change = try XCTUnwrap(baseline.change(current: current))
            XCTAssertEqual(change.amount, 60)
            XCTAssertEqual(change.percent, 20)
            XCTAssertEqual(change.walletChanges["Spot"], 50)
            XCTAssertEqual(change.walletChanges["Earn"], 10)
            XCTAssertEqual(baseline.change(current: wallets(140, 205))?.amount, 45)
            XCTAssertEqual(baseline.sampledAt, Date(timeIntervalSince1970: TimeInterval(midnight + 20_000) / 1000))
        }
    }

    func testInternalWalletTransferHasZeroTotalChange() throws {
        try withStore { store, _ in
            let baseline = try XCTUnwrap(store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight))
            let change = try XCTUnwrap(baseline.change(current: wallets(50, 250)))
            XCTAssertEqual(change.amount, 0)
            XCTAssertEqual(change.percent, 0)
            XCTAssertEqual(change.walletChanges["Spot"], -50)
            XCTAssertEqual(change.walletChanges["Earn"], 50)
        }
    }

    func testBaselineSurvivesRestartWithoutPersistingAPIKey() throws {
        try withStore { store, defaults in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "private-api-key", now: midnight + 1_000)
            let restarted = AccountBaselineStore(defaults: defaults)
            let current = wallets(120, 190)
            let baseline = try XCTUnwrap(restarted.baseline(wallets: current, apiKey: "private-api-key", now: midnight + 60_000))
            XCTAssertEqual(baseline.change(current: current)?.amount, 10)
            for data in defaults.dictionaryRepresentation().values.compactMap({ $0 as? Data }) {
                XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private-api-key"))
            }
        }
    }

    func testObservationBaselineSurvivesRestartWithoutResetting() throws {
        try withStore { store, defaults in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "private-api-key", now: midnight + 3_600_000)
            let restarted = AccountBaselineStore(defaults: defaults)
            let current = wallets(120, 190)
            let baseline = try XCTUnwrap(restarted.baseline(wallets: current, apiKey: "private-api-key", now: midnight + 7_200_000))
            XCTAssertEqual(baseline.change(current: current)?.amount, 10)
            XCTAssertEqual(baseline.basis, .observation)
            for data in defaults.dictionaryRepresentation().values.compactMap({ $0 as? Data }) {
                XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private-api-key"))
            }
        }
    }

    func testDifferentKeyCannotReuseBaseline() throws {
        try withStore { store, _ in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight)
            let other = try XCTUnwrap(store.baseline(wallets: wallets(1000, 2000), apiKey: "b", now: midnight + 60_000))
            XCTAssertEqual(other.basis, .observation)
            XCTAssertEqual(other.change(current: wallets(1000, 2000))?.amount, 0)
        }
    }

    func testNextDayStartsNewObservationOrMidnightBaseline() throws {
        try withStore { store, _ in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight)
            let late = try XCTUnwrap(store.baseline(wallets: wallets(120, 200), apiKey: "a", now: midnight + 86_400_000 + 60_000))
            XCTAssertEqual(late.basis, .observation)
            XCTAssertEqual(late.change(current: wallets(120, 200))?.amount, 0)
            let baseline = try XCTUnwrap(store.baseline(wallets: wallets(150, 250), apiKey: "a", now: midnight + 2 * 86_400_000))
            XCTAssertEqual(baseline.change(current: wallets(160, 260))?.amount, 20)
            XCTAssertEqual(baseline.basis, .utcMidnight)
        }
    }

    func testMidnightWindowDoesNotResetExistingSample() throws {
        try withStore { store, _ in
            _ = try store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight + 1)
            let baseline = try XCTUnwrap(store.baseline(wallets: wallets(110, 210), apiKey: "a", now: midnight + 59_999))
            XCTAssertEqual(baseline.change(current: wallets(110, 210))?.amount, 20)
        }
    }

    func testChangedWalletCoverageIsUnavailableRatherThanPhantomProfitOrLoss() throws {
        try withStore { store, _ in
            let baseline = try XCTUnwrap(store.baseline(wallets: wallets(100, 200), apiKey: "a", now: midnight))
            XCTAssertNil(baseline.change(current: [AccountWallet(name: "Spot", value: 100)]))
            XCTAssertNil(baseline.change(current: wallets(100, 200) + [AccountWallet(name: "New Wallet", value: 50)]))
        }
    }

    func testZeroOrNegativeBaselineDoesNotProduceMisleadingPercentage() throws {
        try withStore { store, _ in
            let baseline = try XCTUnwrap(store.baseline(wallets: wallets(0, 0), apiKey: "a", now: midnight))
            XCTAssertEqual(baseline.change(current: wallets(100, 0))?.amount, 100)
            XCTAssertNil(baseline.change(current: wallets(100, 0))?.percent)
            let negative = try XCTUnwrap(store.baseline(wallets: wallets(-100, 0), apiKey: "b", now: midnight))
            XCTAssertEqual(negative.change(current: wallets(-80, 0))?.amount, 20)
            XCTAssertNil(negative.change(current: wallets(-80, 0))?.percent)
        }
    }

    private func wallets(_ spot: Decimal, _ earn: Decimal) -> [AccountWallet] {
        [AccountWallet(name: "Spot", value: spot), AccountWallet(name: "Earn", value: earn)]
    }

    private func withStore(_ body: (AccountBaselineStore, UserDefaults) throws -> Void) throws {
        let suite = "CandlebarBaselineTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(AccountBaselineStore(defaults: defaults), defaults)
    }
}
