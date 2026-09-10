import FocusLockCore
import SwiftUI

struct StreamSetupView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var newCategory = ""
    @State private var isNamingCategory = false
    @FocusState private var categoryFieldFocused: Bool

    /// A type rather than a sentinel string: any reserved string is either
    /// something a host could type themselves or, as with a NUL, something
    /// that does not survive the trip through AppKit's menus intact.
    private enum CategoryChoice: Hashable {
        case existing(String)
        case new
    }

    private var categorySelection: Binding<CategoryChoice> {
        Binding(
            get: { isNamingCategory ? .new : .existing(controller.config.stream.category) },
            set: { choice in
                switch choice {
                case .new:
                    isNamingCategory = true
                case .existing(let name):
                    isNamingCategory = false
                    guard !name.isEmpty else { return }
                    controller.updateStream { $0.category = name }
                }
            }
        )
    }
    @State private var guestName = ""
    @State private var guestTask = ""

    private func setting<T>(_ key: WritableKeyPath<StreamSettings, T>) -> Binding<T> {
        Binding(get: { controller.config.stream[keyPath: key] }, set: { value in
            controller.updateStream { $0[keyPath: key] = value }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    FLMicroLabel(text: "A little company for your next task")
                    Text("Bring your own task")
                        .font(FLTypography.title)
                    Text("Everyone works on something different. Set a goal, focus together, and catch up during the break.")
                        .font(.callout)
                        .foregroundStyle(Color.flInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                hostingToggle
                presetRow
                taskSetup
                timerControls

                if let entry = controller.checkInEntry {
                    StreamCheckInView(entry: entry).id(entry.id)
                }
                recapCard
                if let message = controller.streamMessage {
                    Text(message).font(.caption).foregroundStyle(Color.flInkSoft)
                }

                // Nothing below here means anything unless you are hosting, and
                // a page of controls that do not apply is a page you learn to
                // scroll past.
                if isHosting {
                    FLRule()
                    hazardWarning
                    streamStage
                    FLRule()
                    audienceWall
                    FLRule()
                    streamSetupDisclosure
                }

                FLRule()
                categorySummary
            }
            .padding(28)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.flInk)
    }

    /// True while hosting, and while a hosted run is still going — turning the
    /// toggle off mid-run must not pull the controls out from under the host.
    private var isHosting: Bool {
        controller.config.stream.enabled || controller.snapshot.task?.shared == true
    }

    private var hostingToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Host a shared session", isOn: setting(\.enabled))
                .toggleStyle(.switch).tint(Color.flAccentDeep)
                .disabled(controller.isSessionActive || controller.snapshot.phase == .breakEnded)
            Text("Off, this is a plain focus timer. On, it opens the stream window, the wall, and everything else you need to host — and waits for you after each break so there is time to check in with chat.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            FLMicroLabel(text: "The window your viewers see")
            HStack {
                Button("Open stream window") { controller.openStreamWindow() }
                    .buttonStyle(FLActionButtonStyle(variant: .primary))
                Spacer()
                Toggle("Dark canvas", isOn: setting(\.darkAppearance)).toggleStyle(.switch).tint(Color.flAccentDeep)
            }
            HStack(spacing: 10) {
                Text("How many blocks today").font(.callout).foregroundStyle(Color.flInkSoft)
                Text("\(controller.config.stream.plannedBlocks)")
                    .font(.callout).monospacedDigit()
                Stepper("How many blocks today", value: setting(\.plannedBlocks), in: 1...12)
                    .labelsHidden()
                Spacer()
            }
            .disabled(controller.isSessionActive)
            Text("Appears on the stream window as \"Block 2 of 4\" while you run, so someone arriving can tell whether it is worth settling in.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamSetupDisclosure: some View {
        DisclosureGroup("Capture setup, preview, and music") {
            VStack(alignment: .leading, spacing: 12) {
                StreamAudienceView()
                    .environmentObject(controller)
                    .frame(height: 370)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Audience preview")
                Text("In OBS, add a macOS Screen Capture source and select the LockIn Stream window. LockIn supplies the timer and prompts; start your broadcast in OBS.")
                    .font(.caption).foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Session music").font(.headline)
                HStack {
                    TextField("Playlist link — Spotify, Apple Music, YouTube", text: setting(\.playlistURL))
                        .flField()
                    Button("Open playlist") { controller.openPlaylist() }
                        .disabled(controller.config.stream.playlistDestination == nil)
                }
                Text("LockIn opens the link and nothing else — it never plays or rebroadcasts audio, and your music app stays out of the capture. Check your platform's music rules first: most commercial tracks are not cleared for streaming, and DMCA-safe libraries exist for exactly this.")
                    .font(.caption).foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
    }

    private var taskSetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(controller.isSessionActive ? "Your next goal" : "Your goal").font(.headline)
            TextField("One thing to move forward, e.g. finish my portfolio intro", text: Binding(
                get: { controller.config.stream.goal },
                set: { value in controller.updateStream { $0.goal = String(value.prefix(160)) } }
            ))
            .flField()
            if isHosting {
                Toggle("Show my goal on stream", isOn: setting(\.showGoal)).toggleStyle(.switch).tint(Color.flAccentDeep)
            }

            HStack(spacing: 10) {
                Text("Category").font(.callout).foregroundStyle(Color.flInkSoft)
                Picker("Category", selection: categorySelection) {
                    ForEach(controller.config.stream.categories, id: \.self) {
                        Text($0).tag(CategoryChoice.existing($0))
                    }
                    Divider()
                    Text("New category…").tag(CategoryChoice.new)
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
            }

            // The field only exists while you are actually naming one, rather
            // than sitting on the page forever for the once-a-month occasion.
            if isNamingCategory {
                HStack {
                    TextField("Name it", text: $newCategory)
                        .flField()
                        .focused($categoryFieldFocused)
                        .onSubmit(addCategory)
                        .frame(maxWidth: 270)
                        .onAppear { categoryFieldFocused = true }
                    Button("Add", action: addCategory)
                        .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") {
                        newCategory = ""
                        isNamingCategory = false
                    }
                    Spacer()
                }
            }
            if controller.isSessionActive {
                Text("Goal and category changes apply to the next block. The audience keeps seeing this block's goal.")
                    .font(.caption).foregroundStyle(Color.flInkSoft)
            }
        }
    }

    /// Placed above everything else: finding this after the broadcast has
    /// already been guarded shut is too late to be useful.
    @ViewBuilder
    private var hazardWarning: some View {
        let hazards = controller.streamHazards
        if !hazards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Guarding these would interrupt your own stream", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.flWarning)
                ForEach(hazards) { hazard in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hazard.app.name).font(.callout)
                            Text(hazard.role.consequence)
                                .font(.caption).foregroundStyle(Color.flInkSoft)
                        }
                        Spacer()
                        Button("Unguard") { controller.unguard(hazard) }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.flCanvasWarm, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.flWarning.opacity(0.4), lineWidth: 1))
        }
    }

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            FLMicroLabel(text: "Start from a session type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StreamPreset.all) { preset in
                        Button { controller.apply(preset) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).font(.callout)
                                Text("\(preset.focusMinutes)/\(preset.breakMinutes) · \(preset.blocks) blocks")
                                    .font(.caption).foregroundStyle(Color.flInkSoft)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(preset.matches(controller.config) ? Color.flAccentSoft : Color.flCanvasWarm,
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.isSessionActive)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var recapCard: some View {
        let recap = controller.streamRecap
        if !recap.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    FLMicroLabel(text: "This run")
                    Spacer()
                    Button("Copy recap") { controller.copyRecap() }
                }
                Text(recap.headline).font(.title3)
                Text(recap.text.split(separator: "\n").dropFirst().joined(separator: " · "))
                    .font(.callout).foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.flCanvasWarm, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Nothing reaches the broadcast from here without passing through the
    /// roster, so this page is the only place a stranger's text is reviewed.
    private var audienceWall: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                FLMicroLabel(text: "The wall · \(controller.roster.admitted.count) working alongside")
                Spacer()
                Toggle("Show on stream", isOn: setting(\.showRoster)).toggleStyle(.switch).tint(Color.flAccentDeep)
            }
            Text("Everyone who joins gets their name up. Once there are more people than fit, the wall turns pages on its own so nobody sits unseen.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Show tasks without asking me first", isOn: Binding(
                get: { controller.config.stream.autoApproveTasks },
                set: controller.setAudienceAutoApprove
            ))
            .toggleStyle(.switch).tint(Color.flAccentDeep)
            Text("Leave this off unless chat is moving faster than you can read. Whatever appears on the wall is on your broadcast, under your name.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            chatConnection

            Text("Tell me when someone is waiting").font(.headline)
            HStack(spacing: 20) {
                Toggle("Play a sound", isOn: setting(\.alertSound))
                    .toggleStyle(.switch).tint(Color.flAccentDeep)
                Toggle("Show a notification", isOn: setting(\.alertBanner))
                    .toggleStyle(.switch).tint(Color.flAccentDeep)
                Spacer()
            }
            Text("The Stream tab always shows a count and the menu bar shows a dot, silently. These two can reach the broadcast, which is why they are off to begin with: a sound goes out if OBS is capturing desktop audio, and a banner is drawn on screen if you capture a display rather than a window. The notification never contains anyone's words — only how many are waiting. Arrivals are grouped, so a rush is one interruption rather than twenty.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !controller.roster.held.isEmpty {
                HStack {
                    Text("Waiting for you").font(.headline)
                    Spacer()
                    Button("Show all \(controller.roster.held.count)") { controller.roster.approveAll() }
                }
                ForEach(controller.roster.held) { task in
                    guestRow(task, isOnScreen: false)
                }
            }

            if !controller.roster.admitted.isEmpty {
                Text("On screen now").font(.headline)
                ForEach(controller.roster.admitted) { task in
                    guestRow(task, isOnScreen: true)
                }
            }

            HStack {
                TextField("Name", text: $guestName)
                    .flField().frame(maxWidth: 150)
                TextField("What they're working on", text: $guestTask)
                    .flField()
                    .onSubmit(addGuest)
                Button("Add", action: addGuest)
                    .disabled(guestName.trimmingCharacters(in: .whitespaces).isEmpty
                              || guestTask.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack {
                Text("Blocked words: \(controller.roster.blockedTerms.count) in use")
                    .font(.caption).foregroundStyle(Color.flInkSoft)
                Spacer()
                Button("Edit list") { controller.revealBlockedWordsFile() }
            }
            Text("Spacing, punctuation, accents, repeated letters, and digits standing in for letters are all folded before matching, so one entry catches its variants. Two deliberate attempts and that person is blocked for the stream. No list is complete — approve-first is what actually protects you.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("Or add someone by hand — it goes through the same queue and the same rules as a chat message.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chatConnection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Twitch chat").font(.headline)
            HStack {
                TextField("Your channel — piping16, or paste your channel link",
                          text: setting(\.twitchChannel))
                    .flField()
                    .disabled(controller.chatState.isLive)
                if controller.chatState.isLive {
                    Button("Disconnect") { controller.disconnectChat() }
                } else {
                    Button("Connect") { controller.connectChat() }
                        .disabled(controller.config.stream.twitchChannel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            HStack(spacing: 7) {
                Circle()
                    .fill(controller.chatState.isLive ? Color.flAccent : Color.flHairline)
                    .frame(width: 7, height: 7)
                Text(controller.chatState.summary)
                    .font(.caption).foregroundStyle(Color.flInkSoft)
            }
            Text("Read-only and anonymous — no login, and LockIn never posts to your chat. Viewers type \(AudienceCommand.advertised) to appear on the wall and !done to check theirs off.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guestRow(_ task: AudienceTask, isOnScreen: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name).font(.caption).foregroundStyle(Color.flInkSoft)
                Text(task.text).font(.callout).strikethrough(task.isDone)
            }
            Spacer()
            if !isOnScreen {
                Button("Show") { controller.roster.approve(task.id) }
            }
            Button(isOnScreen ? "Take down" : "Skip") { controller.roster.remove(task.id) }
            Button("Block") { controller.roster.block(name: task.name) }
                .foregroundStyle(Color.flDestructive)
        }
        .padding(.vertical, 2)
    }

    private func addGuest() {
        controller.submitAudienceTask(name: guestName, text: guestTask)
        guestName = ""
        guestTask = ""
    }

    private func addCategory() {
        let name = newCategory
        controller.updateStream { _ = $0.addCategory(name) }
        newCategory = ""
        isNamingCategory = false
    }

    private var timerControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if controller.snapshot.phase != .idle {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    FLMicroLabel(text: controller.snapshot.phase.displayName)
                    Text(controller.displayCountdown)
                        .font(.system(.title, design: .monospaced))
                        .monospacedDigit()
                    Spacer()
                }
            }
            HStack(spacing: 24) {
                FLDurationField(label: "Focus", minutes: Binding(get: { controller.config.focusMinutes }, set: controller.updateFocusMinutes), range: AppConfig.focusMinutesRange)
                FLDurationField(label: "Break", minutes: Binding(get: { controller.config.breakMinutes }, set: controller.updateBreakMinutes), range: 0...60)
            }
            .disabled(controller.isSessionActive)
            HStack {
                if controller.isSessionActive {
                    Button("End session") { controller.stopSession() }
                        .buttonStyle(FLActionButtonStyle(variant: .secondary))
                } else {
                    Button(controller.snapshot.phase == .breakEnded ? "Start next block" : "Start focus") { controller.startFocus() }
                        .buttonStyle(FLActionButtonStyle(variant: .primary))
                    if controller.snapshot.phase == .breakEnded {
                        Button("Finish for now") { controller.stopSession() }
                    }
                }
            }
        }
    }

    private var categorySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            FLMicroLabel(text: "Your focus by category · This week")
            let rows = categoryMinutes
            if rows.isEmpty {
                Text("Completed blocks will appear here with their category.")
                    .font(.callout).foregroundStyle(Color.flInkSoft)
            }
            ForEach(rows, id: \.name) { row in
                HStack {
                    Text(row.name)
                    Spacer()
                    Text("\(row.minutes) min").monospacedDigit()
                }.font(.callout)
            }
        }
    }

    private var categoryMinutes: [(name: String, minutes: Int)] {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
        let completed = controller.history.filter { $0.status == .completed && (week?.contains($0.startedAt) ?? false) }
        let grouped = Dictionary(grouping: completed) { $0.task?.category ?? "Uncategorized" }
        return grouped.map { (name: $0.key, minutes: $0.value.reduce(0) { $0 + $1.focusMinutes }) }
            .sorted { $0.minutes == $1.minutes ? $0.name < $1.name : $0.minutes > $1.minutes }
    }
}

private struct StreamCheckInView: View {
    @EnvironmentObject private var controller: MenuBarController
    let entry: SessionHistoryEntry
    @State private var outcome: CheckInOutcome = .progress
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FLMicroLabel(text: "Break check-in")
            Text("How did your task go?").font(.title2)
            if let goal = entry.task?.goal, !goal.isEmpty {
                Text(goal).font(.callout).foregroundStyle(Color.flInkSoft)
            }
            Picker("Progress", selection: $outcome) {
                ForEach(CheckInOutcome.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            TextField("A private note for next time (optional)", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .flField()
                .onChange(of: note) { note = String($0.prefix(500)) }
            Button(entry.checkIn == nil ? "Save check-in" : "Update check-in") {
                controller.saveCheckIn(outcome: outcome, note: note)
            }
            Text("Ask chat: what moved forward? Then stretch, get some water, and choose your next small goal.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
        }
        .padding(18)
        .background(Color.flCanvasWarm, in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            outcome = entry.checkIn?.outcome ?? .progress
            note = entry.checkIn?.note ?? ""
        }
    }
}
