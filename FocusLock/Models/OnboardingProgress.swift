import Foundation

/// Availability is separate from the saved guard list: sites need at least
/// one authorised browser, and disabled entries do not count.
public struct ProtectionAvailability: Codable, Equatable {
    public var apps: Int
    public var sites: Int
    public var authorisedBrowsers: Int

    public init(apps: Int, sites: Int, authorisedBrowsers: Int) {
        self.apps = max(0, apps)
        self.sites = max(0, sites)
        self.authorisedBrowsers = max(0, authorisedBrowsers)
    }

    public var isAvailable: Bool { apps > 0 || (sites > 0 && authorisedBrowsers > 0) }
}

/// A local first-use baseline, with no app names, domains, goals or account ID.
/// Existing installs are excluded because their first-use dates are unknown.
public struct OnboardingProgress: Codable, Equatable {
    public var cohortStartedAt: Date?
    public var guideDismissedAt: Date?
    public var guideCompletedAt: Date?
    public var timerOnlyChosen = false
    public var notificationsDeferred = false
    public var preferredBrowserBundleID: String?
    public private(set) var firstBlockStartedAt: Date?
    public private(set) var protectionAtFirstStart: ProtectionAvailability?
    public private(set) var firstFullBlockCompletedAt: Date?
    public private(set) var activatedAt: Date?
    public private(set) var firstInterceptionAt: Date?
    public private(set) var day7ReturnedAt: Date?
    public private(set) var activeBlock: Block?

    public struct Block: Codable, Equatable {
        public var startedAt: Date
        public var plannedMinutes: Int
        public var protection: ProtectionAvailability
        public var previousEntryIDs: [UUID]
    }

    public init(isNewInstall: Bool, now: Date = Date()) {
        cohortStartedAt = isNewInstall ? now : nil
    }

    public var timeToFirstStartSeconds: TimeInterval? {
        guard let cohortStartedAt, let firstBlockStartedAt else { return nil }
        return max(0, firstBlockStartedAt.timeIntervalSince(cohortStartedAt))
    }

    public var timeToActivationSeconds: TimeInterval? {
        guard let cohortStartedAt, let activatedAt else { return nil }
        return max(0, activatedAt.timeIntervalSince(cohortStartedAt))
    }

    public mutating func recordVisit(at date: Date) {
        guard let cohortStartedAt, day7ReturnedAt == nil else { return }
        let elapsed = date.timeIntervalSince(cohortStartedAt)
        // Fixed elapsed-time window; changing timezone does not change a cohort.
        if elapsed >= 7 * 86_400 && elapsed < 8 * 86_400 { day7ReturnedAt = date }
    }

    public mutating func recordStart(at date: Date, minutes: Int, protection: ProtectionAvailability,
                                    history: [SessionHistoryEntry] = []) {
        guard cohortStartedAt != nil else { return }
        if firstBlockStartedAt == nil {
            firstBlockStartedAt = date
            protectionAtFirstStart = protection
        }
        guard activatedAt == nil else { return }
        // Persisted ISO dates have one-second precision. Exclude earlier
        // attempts in that same second so a rapid restart cannot consume them.
        let previousIDs = history.filter { abs($0.startedAt.timeIntervalSince(date)) < 1 }.map(\.id)
        activeBlock = Block(startedAt: date, plannedMinutes: minutes, protection: protection, previousEntryIDs: previousIDs)
    }

    public mutating func updateProtection(_ protection: ProtectionAvailability) {
        activeBlock?.protection = protection
    }

    public mutating func recordInterception(at date: Date) {
        guard cohortStartedAt != nil, firstInterceptionAt == nil else { return }
        firstInterceptionAt = date
    }

    public mutating func reconcile(history: [SessionHistoryEntry]) {
        guard let block = activeBlock,
              let entry = history.first(where: {
                  abs($0.startedAt.timeIntervalSince(block.startedAt)) < 1 && !block.previousEntryIDs.contains($0.id)
              })
        else { return }
        // History also labels an early skip as completed. Activation requires
        // the original planned duration, rather than that shortened duration.
        let completedFullBlock = entry.status == .completed
            && entry.endedAt.timeIntervalSince(block.startedAt) >= Double(block.plannedMinutes * 60) - 1
        if completedFullBlock {
            if firstFullBlockCompletedAt == nil { firstFullBlockCompletedAt = entry.endedAt }
            if block.protection.isAvailable && activatedAt == nil { activatedAt = entry.endedAt }
        }
        activeBlock = nil
    }
}
