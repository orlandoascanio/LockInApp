import FocusLockCore
import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FLPageHeader(title: "Schedules", subtitle: subtitle) {
                Button {
                    controller.addSchedule()
                } label: {
                    Label("Add schedule", systemImage: "plus")
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 34))
            }

            if controller.config.schedules.isEmpty {
                FLEmptyState(
                    systemImage: "calendar.badge.clock",
                    title: "No schedules",
                    detail: "Add one and Quietwhile starts focus on its own — say, weekdays from 9:00 to 12:00 — and keeps the blocks rolling until the window closes."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !controller.launchAtLogin {
                            loginHint
                                .padding(.horizontal, FLLayout.pageInset)
                                .padding(.bottom, 16)
                        }

                        ForEach(controller.config.schedules) { schedule in
                            FLRule()
                            ScheduleRow(schedule: schedule)
                                .flBand(vertical: 18)
                        }

                        FLRule()

                        Text("Inside a window, each break rolls straight into the next block. Stopping a session skips the rest of that window; the next one starts as normal. A block still running when the window closes gets to finish.")
                            .font(FLTypography.caption)
                            .foregroundStyle(Color.flInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .flBand(vertical: 14)
                    }
                }
                .flScrollEdges(top: 0)
            }
        }
    }

    private var subtitle: String {
        if let active = controller.activeScheduleOccurrence {
            return "\(active.schedule.name) is on until \(MenuBarController.shortTime(active.end))"
        }
        if let next = controller.nextScheduleOccurrence {
            let formatter = DateFormatter()
            formatter.dateFormat = Calendar.current.isDateInToday(next.start) ? "'today at' h:mm a" : "EEEE 'at' h:mm a"
            return "Next: \(next.schedule.name), \(formatter.string(from: next.start))"
        }
        return "Focus that starts itself"
    }

    private var loginHint: some View {
        FLCallout(tone: .warning, systemImage: "power", title: "Schedules only run while Quietwhile is open.") {
            Button("Open Quietwhile at login") {
                controller.setLaunchAtLogin(true)
            }
            .buttonStyle(FLLinkButtonStyle(tint: .flWarningInk))
        }
    }
}

private struct ScheduleRow: View {
    @EnvironmentObject private var controller: MenuBarController
    let schedule: FocusSchedule

    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Name", text: binding(\.name))
                    .font(.system(size: 15, weight: .semibold))
                    .flField(width: 220)

                Spacer()

                if controller.activeScheduleOccurrence?.schedule.id == schedule.id {
                    FLBadge(text: "On now")
                }

                Button {
                    controller.requestRemoveSchedule(schedule)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.flClayInk)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete \(schedule.name)")
                .accessibilityLabel("Delete \(schedule.name)")

                FLSwitch(isOn: binding(\.isEnabled), label: "Enable \(schedule.name)")
            }

            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    dayChip(weekday)
                }
            }

            HStack(spacing: 18) {
                timePicker("From", minute: binding(\.startMinute))
                timePicker("To", minute: binding(\.endMinute))
                Text(durationLabel)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                Spacer()
            }

            HStack(alignment: .center, spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strict blocks")
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInk)
                    Text("No ending, skipping, or quitting during this schedule's focus blocks.")
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                }
                Spacer(minLength: FLSpacing.md)
                FLSwitch(isOn: binding(\.strict), label: "Strict blocks for \(schedule.name)")
            }
        }
        .opacity(schedule.isEnabled ? 1 : 0.6)
    }

    private var durationLabel: String {
        let minutes = schedule.durationMinutes
        let overnight = schedule.endMinute < schedule.startMinute ? " · ends next day" : ""
        return RunRecap.duration(minutes) + overnight
    }

    private func dayChip(_ weekday: Int) -> some View {
        let isOn = schedule.weekdays.contains(weekday)
        let symbol = Calendar.current.shortWeekdaySymbols[weekday - 1]
        return Button {
            var updated = schedule
            if isOn {
                updated.weekdays.remove(weekday)
            } else {
                updated.weekdays.insert(weekday)
            }
            controller.updateSchedule(updated)
        } label: {
            Text(symbol)
                .font(.system(size: 12, weight: isOn ? .semibold : .medium))
                .foregroundStyle(isOn ? Color.flOnAccent : Color.flInkSoft)
                .frame(width: 44, height: 26)
                .background(Capsule().fill(isOn ? Color.flAccentDeep : Color.flSunken))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func timePicker(_ label: String, minute: Binding<Int>) -> some View {
        FLTimePicker(label: label, minute: minute)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<FocusSchedule, Value>) -> Binding<Value> {
        Binding(
            get: { schedule[keyPath: keyPath] },
            set: { value in
                var updated = schedule
                updated[keyPath: keyPath] = value
                controller.updateSchedule(updated)
            }
        )
    }
}
