import FocusLockCore
import XCTest

final class OnboardingProgressTests: XCTestCase {
    private let opened = Date(timeIntervalSince1970: 1_800_000_000)
    private let appProtection = ProtectionAvailability(apps: 1, sites: 0, authorisedBrowsers: 0)
    private let timerOnly = ProtectionAvailability(apps: 0, sites: 0, authorisedBrowsers: 0)

    func testSitesNeedBrowserAccessAndAppsDoNot() {
        XCTAssertFalse(ProtectionAvailability(apps: 0, sites: 2, authorisedBrowsers: 0).isAvailable)
        XCTAssertTrue(ProtectionAvailability(apps: 0, sites: 2, authorisedBrowsers: 1).isAvailable)
        XCTAssertFalse(ProtectionAvailability(apps: 0, sites: 0, authorisedBrowsers: 1).isAvailable)
        XCTAssertTrue(appProtection.isAvailable)
    }

    func testGuideDismissalIsSeparateFromCompletionAndActivation() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        progress.guideDismissedAt = opened.addingTimeInterval(10)
        XCTAssertNil(progress.guideCompletedAt)
        XCTAssertNil(progress.firstBlockStartedAt)
        XCTAssertNil(progress.activatedAt)
    }

    func testCompletedProtectedBlockActivatesWithoutAnInterception() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        let start = opened.addingTimeInterval(40)
        progress.recordStart(at: start, minutes: 25, protection: appProtection)
        progress.reconcile(history: [entry(start: start, elapsedMinutes: 25)])
        XCTAssertEqual(progress.timeToFirstStartSeconds, 40)
        XCTAssertEqual(progress.protectionAtFirstStart, appProtection)
        XCTAssertEqual(progress.firstFullBlockCompletedAt, start.addingTimeInterval(1_500))
        XCTAssertEqual(progress.timeToActivationSeconds, 1_540)
        XCTAssertNil(progress.firstInterceptionAt)
        XCTAssertNil(progress.activeBlock)
    }

    func testTimerOnlyCompletionDoesNotActivateAndLaterProtectionCan() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        progress.recordStart(at: opened, minutes: 25, protection: timerOnly)
        let first = entry(start: opened, elapsedMinutes: 25)
        progress.reconcile(history: [first])
        XCTAssertEqual(progress.firstFullBlockCompletedAt, first.endedAt)
        XCTAssertNil(progress.activatedAt)
        let secondStart = opened.addingTimeInterval(3_600)
        progress.recordStart(at: secondStart, minutes: 25, protection: appProtection)
        progress.reconcile(history: [first, entry(start: secondStart, elapsedMinutes: 25)])
        XCTAssertEqual(progress.activatedAt, secondStart.addingTimeInterval(1_500))
        XCTAssertEqual(progress.firstFullBlockCompletedAt, first.endedAt)
        XCTAssertEqual(progress.protectionAtFirstStart, timerOnly)
    }

    func testEarlySkipDoesNotCountAsFullCompletion() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        progress.recordStart(at: opened, minutes: 25, protection: appProtection)
        // TimerEngine logs the actual worked duration as completed on a skip.
        progress.reconcile(history: [entry(start: opened, elapsedMinutes: 3)])
        XCTAssertNil(progress.firstFullBlockCompletedAt)
        XCTAssertNil(progress.activatedAt)
        XCTAssertNil(progress.activeBlock)
    }

    func testCancelledAndAbandonedBlocksNeverActivate() {
        for status in [SessionHistoryStatus.cancelled, .abandoned] {
            var progress = OnboardingProgress(isNewInstall: true, now: opened)
            progress.recordStart(at: opened, minutes: 25, protection: appProtection)
            progress.reconcile(history: [entry(start: opened, elapsedMinutes: 25, status: status)])
            XCTAssertNil(progress.firstFullBlockCompletedAt)
            XCTAssertNil(progress.activatedAt)
        }
    }

    func testRapidRestartDoesNotConsumePreviousCancelledAttempt() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        let previous = entry(start: opened, elapsedMinutes: 0, status: .cancelled)
        let restart = opened.addingTimeInterval(0.5)
        progress.recordStart(at: restart, minutes: 25, protection: appProtection, history: [previous])
        progress.reconcile(history: [previous])
        XCTAssertNotNil(progress.activeBlock)
        progress.reconcile(history: [previous, entry(start: restart, elapsedMinutes: 25)])
        XCTAssertNotNil(progress.activatedAt)
    }

    func testProtectionChangesDuringTheBlockAreReflectedAtCompletion() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        progress.recordStart(at: opened, minutes: 25, protection: appProtection)
        progress.updateProtection(timerOnly)
        progress.reconcile(history: [entry(start: opened, elapsedMinutes: 25)])
        XCTAssertNil(progress.activatedAt)

        let next = opened.addingTimeInterval(3_600)
        progress.recordStart(at: next, minutes: 25, protection: timerOnly)
        progress.updateProtection(ProtectionAvailability(apps: 0, sites: 1, authorisedBrowsers: 1))
        progress.reconcile(history: [entry(start: next, elapsedMinutes: 25)])
        XCTAssertNotNil(progress.activatedAt)
    }

    func testDaySevenReturnHasAnExactWindowAndDoesNotRequireActivation() {
        var progress = OnboardingProgress(isNewInstall: true, now: opened)
        progress.recordVisit(at: opened.addingTimeInterval(7 * 86_400 - 1))
        XCTAssertNil(progress.day7ReturnedAt)
        let returnDate = opened.addingTimeInterval(7 * 86_400)
        progress.recordVisit(at: returnDate)
        progress.recordVisit(at: returnDate.addingTimeInterval(200))
        XCTAssertEqual(progress.day7ReturnedAt, returnDate)

        var late = OnboardingProgress(isNewInstall: true, now: opened)
        late.recordVisit(at: opened.addingTimeInterval(8 * 86_400))
        XCTAssertNil(late.day7ReturnedAt)
    }

    func testExistingInstallDoesNotBecomeANewCohort() {
        var progress = OnboardingProgress(isNewInstall: false, now: opened)
        progress.recordStart(at: opened, minutes: 25, protection: appProtection)
        progress.recordVisit(at: opened.addingTimeInterval(7 * 86_400))
        progress.recordInterception(at: opened)
        XCTAssertNil(progress.cohortStartedAt)
        XCTAssertNil(progress.firstBlockStartedAt)
        XCTAssertNil(progress.day7ReturnedAt)
        XCTAssertNil(progress.firstInterceptionAt)
    }

    func testBaselineAndPendingBlockSurviveRelaunchAndReconcilePersistedHistory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OnboardingStore(baseDirectory: directory)
        let started = opened.addingTimeInterval(40.6)
        var progress = store.load(isNewInstall: true, now: opened)
        progress.guideDismissedAt = opened
        progress.timerOnlyChosen = true
        progress.notificationsDeferred = true
        progress.recordStart(at: started, minutes: 25, protection: appProtection)
        try store.save(progress)

        var restored = store.load(isNewInstall: false, now: opened.addingTimeInterval(5_000))
        XCTAssertEqual(restored.cohortStartedAt, opened)
        XCTAssertEqual(restored.guideDismissedAt, opened)
        XCTAssertTrue(restored.timerOnlyChosen)
        XCTAssertTrue(restored.notificationsDeferred)
        // ISO dates in both the metrics file and session history drop fractions.
        restored.reconcile(history: [entry(start: opened.addingTimeInterval(40), elapsedMinutes: 25)])
        XCTAssertNotNil(restored.activatedAt)
        try store.save(restored)
        XCTAssertEqual(store.load(isNewInstall: true, now: opened).activatedAt, restored.activatedAt)
    }

    func testCorruptBaselineIsPreservedAndExcludedRatherThanRecounted() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OnboardingStore(baseDirectory: directory)
        try Data("unreadable".utf8).write(to: store.url)
        XCTAssertNil(store.load(isNewInstall: true, now: opened).cohortStartedAt)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("onboarding-progress.json.invalid-") })
    }

    private func entry(start: Date, elapsedMinutes: Int, status: SessionHistoryStatus = .completed) -> SessionHistoryEntry {
        SessionHistoryEntry(startedAt: start, endedAt: start.addingTimeInterval(Double(elapsedMinutes * 60)),
                            focusMinutes: elapsedMinutes, breakMinutes: 5, status: status,
                            blockedAppsCount: 1, strictMode: false)
    }
}
