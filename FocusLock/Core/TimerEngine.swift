import Foundation

public final class TimerEngine {
    public private(set) var snapshot: TimerSnapshot {
        didSet {
            onChange?(snapshot)
        }
    }

    public var onChange: ((TimerSnapshot) -> Void)?

    private let stateStore: StateStore
    private let historyStore: SessionHistoryStore
    private let notificationService: NotificationSending
    private let clock: () -> Date

    private var lastPersistedPhase: SessionPhase?

    public init(
        stateStore: StateStore,
        historyStore: SessionHistoryStore,
        notificationService: NotificationSending,
        clock: @escaping () -> Date = Date.init
    ) {
        self.stateStore = stateStore
        self.historyStore = historyStore
        self.notificationService = notificationService
        self.clock = clock
        self.snapshot = TimerSnapshot()
        restore(now: clock())
    }

    public func startFocus(
        focusMinutes: Int,
        breakMinutes: Int,
        blockedAppsCount: Int,
        strictMode: Bool,
        now: Date? = nil
    ) {
        let startedAt = now ?? clock()
        let state = SessionState(
            state: .focus,
            startedAt: startedAt,
            focusMinutes: focusMinutes,
            breakMinutes: breakMinutes,
            blockedAppsCount: blockedAppsCount,
            strictMode: strictMode
        )

        try? stateStore.saveSessionState(state)
        lastPersistedPhase = .focus
        notificationService.focusStarted(minutes: state.focusMinutes)
        snapshot = makeSnapshot(for: state, now: startedAt)
    }

    public func stopSession(now: Date? = nil) {
        guard let state = stateStore.loadSessionState(), state.state == .focus || state.state == .break || state.state == .breakEnded else {
            snapshot = TimerSnapshot(phase: .cancelled)
            return
        }

        let endedAt = now ?? clock()
        if state.state == .focus {
            appendHistory(for: state, endedAt: endedAt, status: .cancelled)
        }
        try? stateStore.clearSessionState()
        lastPersistedPhase = .cancelled
        notificationService.sessionCancelled()
        snapshot = TimerSnapshot(
            phase: .cancelled,
            sessionStartedAt: state.startedAt,
            remainingSeconds: 0,
            focusMinutes: state.focusMinutes,
            breakMinutes: state.breakMinutes
        )
    }

    public func startBreakExtension(
        minutes: Int = 2,
        focusMinutes: Int,
        blockedAppsCount: Int,
        strictMode: Bool,
        now: Date? = nil
    ) {
        let currentDate = now ?? clock()
        let normalizedFocusMinutes = max(1, focusMinutes)
        let breakStartedAt = currentDate.addingTimeInterval(-TimeInterval(normalizedFocusMinutes * 60))
        let state = SessionState(
            state: .break,
            startedAt: breakStartedAt,
            focusMinutes: normalizedFocusMinutes,
            breakMinutes: max(1, minutes),
            blockedAppsCount: blockedAppsCount,
            strictMode: strictMode
        )

        try? stateStore.saveSessionState(state)
        lastPersistedPhase = .break
        notificationService.breakStarted(minutes: state.breakMinutes)
        snapshot = makeSnapshot(for: state, now: currentDate)
    }

    public func endCycle() {
        try? stateStore.clearSessionState()
        lastPersistedPhase = .idle
        snapshot = TimerSnapshot(
            phase: .idle,
            focusMinutes: snapshot.focusMinutes,
            breakMinutes: snapshot.breakMinutes
        )
    }

    public func restore(now: Date? = nil) {
        refresh(now: now ?? clock())
    }

    public func refresh(now: Date? = nil) {
        let currentDate = now ?? clock()

        guard let state = stateStore.loadSessionState() else {
            if snapshot.phase == .focus || snapshot.phase == .break {
                snapshot = TimerSnapshot()
            }
            return
        }

        switch state.state {
        case .focus:
            refreshFocus(state, now: currentDate)
        case .break:
            refreshBreak(state, now: currentDate)
        case .breakEnded:
            snapshot = makeSnapshot(for: state, now: currentDate)
        case .idle, .paused, .completed, .cancelled:
            try? stateStore.clearSessionState()
            snapshot = TimerSnapshot(phase: state.state)
        }
    }

    private func refreshFocus(_ state: SessionState, now: Date) {
        let focusEndsAt = state.startedAt.addingTimeInterval(TimeInterval(state.focusMinutes * 60))

        guard now >= focusEndsAt else {
            snapshot = makeSnapshot(for: state, now: now)
            return
        }

        if state.breakMinutes <= 0 {
            complete(state, endedAt: focusEndsAt)
            return
        }

        appendHistory(for: state, endedAt: focusEndsAt, status: .completed)

        var breakState = state
        breakState.state = .break
        try? stateStore.saveSessionState(breakState)

        if lastPersistedPhase != .break {
            notificationService.focusCompleted()
            notificationService.breakStarted(minutes: breakState.breakMinutes)
        }

        lastPersistedPhase = .break
        refreshBreak(breakState, now: now)
    }

    private func refreshBreak(_ state: SessionState, now: Date) {
        let breakEndsAt = state.startedAt.addingTimeInterval(TimeInterval((state.focusMinutes + state.breakMinutes) * 60))

        guard now >= breakEndsAt else {
            snapshot = makeSnapshot(for: state, now: now)
            return
        }

        markBreakEnded(state, now: breakEndsAt)
    }

    private func complete(_ state: SessionState, endedAt: Date) {
        appendHistory(for: state, endedAt: endedAt, status: .completed)
        try? stateStore.clearSessionState()
        lastPersistedPhase = .completed
        if state.state == .focus {
            notificationService.focusCompleted()
        }
        snapshot = TimerSnapshot(
            phase: .completed,
            sessionStartedAt: state.startedAt,
            remainingSeconds: 0,
            focusMinutes: state.focusMinutes,
            breakMinutes: state.breakMinutes
        )
    }

    private func markBreakEnded(_ state: SessionState, now: Date) {
        var breakEndedState = state
        breakEndedState.state = .breakEnded
        try? stateStore.saveSessionState(breakEndedState)

        if lastPersistedPhase != .breakEnded {
            notificationService.breakEnded()
        }

        lastPersistedPhase = .breakEnded
        snapshot = makeSnapshot(for: breakEndedState, now: now)
    }

    private func appendHistory(
        for state: SessionState,
        endedAt: Date,
        status: SessionHistoryStatus
    ) {
        let entry = SessionHistoryEntry(
            startedAt: state.startedAt,
            endedAt: endedAt,
            focusMinutes: state.focusMinutes,
            breakMinutes: state.breakMinutes,
            status: status,
            blockedAppsCount: state.blockedAppsCount,
            strictMode: state.strictMode
        )

        try? historyStore.append(entry)
    }

    private func makeSnapshot(for state: SessionState, now: Date) -> TimerSnapshot {
        let phaseEndsAt: Date

        switch state.state {
        case .focus:
            phaseEndsAt = state.startedAt.addingTimeInterval(TimeInterval(state.focusMinutes * 60))
        case .break:
            phaseEndsAt = state.startedAt.addingTimeInterval(TimeInterval((state.focusMinutes + state.breakMinutes) * 60))
        case .breakEnded, .idle, .paused, .completed, .cancelled:
            phaseEndsAt = now
        }

        lastPersistedPhase = state.state

        return TimerSnapshot(
            phase: state.state,
            sessionStartedAt: state.startedAt,
            phaseEndsAt: phaseEndsAt,
            remainingSeconds: phaseEndsAt.timeIntervalSince(now),
            focusMinutes: state.focusMinutes,
            breakMinutes: state.breakMinutes
        )
    }
}
