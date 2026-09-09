import FocusLockCore
import SwiftUI

struct StreamSetupView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var newCategory = ""
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

                hazardWarning
                presetRow

                HStack {
                    Button("Open stream window") { controller.openStreamWindow() }
                        .buttonStyle(FLActionButtonStyle(variant: .primary))
                    Spacer()
                    Toggle("Dark canvas", isOn: setting(\.darkAppearance)).toggleStyle(.switch)
                }

                timerControls
                if let entry = controller.checkInEntry {
                    StreamCheckInView(entry: entry).id(entry.id)
                }
                recapCard
                if let message = controller.streamMessage {
                    Text(message).font(.caption).foregroundStyle(Color.flInkSoft)
                }
                FLRule()
                taskSetup
                FLRule()
                audienceWall
                FLRule()
                stagecraft
                FLRule()

                DisclosureGroup("Audience preview & capture setup") {
                    VStack(alignment: .leading, spacing: 12) {
                        StreamAudienceView()
                            .environmentObject(controller)
                            .frame(height: 370)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Audience preview")
                        Text("In OBS, add a macOS Screen Capture source and select the LockIn Stream window. LockIn supplies the timer and prompts; start your broadcast in OBS.")
                            .font(.caption).foregroundStyle(Color.flInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(.top, 12)
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

    private var taskSetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Host a shared session", isOn: setting(\.enabled))
                .disabled(controller.isSessionActive || controller.snapshot.phase == .breakEnded)
            Text("Shared sessions wait for you after the break, leaving time to check in with chat.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
            Text(controller.isSessionActive ? "Your next goal" : "Your goal").font(.headline)
            TextField("One thing to move forward, e.g. finish my portfolio intro", text: Binding(
                get: { controller.config.stream.goal },
                set: { value in controller.updateStream { $0.goal = String(value.prefix(160)) } }
            ))
            .textFieldStyle(.roundedBorder)
            Toggle("Show my goal on stream", isOn: setting(\.showGoal))
            HStack {
                Picker("Category", selection: setting(\.category)) {
                    ForEach(controller.config.stream.categories, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 270)
                Spacer()
            }
            HStack {
                TextField("New category", text: $newCategory)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCategory)
                Button("Add category", action: addCategory)
                    .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            Text("Presets set durations, category, and the line the audience sees. Your goal is left alone.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
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
                Toggle("Show on stream", isOn: setting(\.showRoster)).toggleStyle(.switch)
            }
            Text("Everyone who joins gets their name up. Once there are more people than fit, the wall turns pages on its own so nobody sits unseen.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Show tasks without asking me first", isOn: Binding(
                get: { controller.config.stream.autoApproveTasks },
                set: controller.setAudienceAutoApprove
            ))
            Text("Leave this off unless chat is moving faster than you can read. Whatever appears on the wall is on your broadcast, under your name.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tell me when someone is waiting").font(.headline)
            HStack(spacing: 20) {
                Toggle("Play a sound", isOn: setting(\.alertSound))
                Toggle("Show a notification", isOn: setting(\.alertBanner))
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
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 150)
                TextField("What they're working on", text: $guestTask)
                    .textFieldStyle(.roundedBorder)
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

            Text("Add someone by hand, or connect chat later — viewers type \(AudienceCommand.advertised) to appear here, and !done to check theirs off.")
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

    private var stagecraft: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper("Blocks planned: \(controller.config.stream.plannedBlocks)",
                    value: setting(\.plannedBlocks), in: 1...12)
                .frame(maxWidth: 270)
                .disabled(controller.isSessionActive)
            Text("The audience sees this as \"Block 2 of 4\", so people can tell how long you will be here.")
                .font(.caption).foregroundStyle(Color.flInkSoft)

            Text("Session music").font(.headline)
            HStack {
                TextField("Playlist link — Spotify, Apple Music, YouTube", text: setting(\.playlistURL))
                    .textFieldStyle(.roundedBorder)
                Button("Open playlist") { controller.openPlaylist() }
                    .disabled(controller.config.stream.playlistDestination == nil)
            }
            Text("LockIn opens the link and nothing else — it never plays or rebroadcasts audio, and your music app stays out of the capture. Check your platform's music rules first: most commercial tracks are not cleared for streaming, and DMCA-safe libraries exist for exactly this.")
                .font(.caption).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addCategory() {
        controller.updateStream { _ = $0.addCategory(newCategory) }
        newCategory = ""
    }

    private var timerControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FLMicroLabel(text: controller.snapshot.phase.displayName)
                Spacer()
                Text(controller.displayCountdown).font(.system(.title, design: .monospaced))
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
                .textFieldStyle(.roundedBorder)
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
