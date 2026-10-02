import FocusLockCore
import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !controller.launchAtLogin, !controller.config.schedules.isEmpty {
                loginHint
            }

            if controller.config.schedules.isEmpty {
                FLEmptyState(
                    systemImage: "calendar.badge.clock",
                    title: "No schedules",
                    detail: "Add one and LockIn starts focus on its own — say, weekdays from 9:00 to 12:00 — and keeps the blocks rolling until the window closes."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(controller.config.schedules) { schedule in
                            FLRule()
                            ScheduleRow(schedule: schedule)
                        }
                        FLRule()
                        Text("Inside a window, each break rolls straight into the next block. Stopping a session skips the rest of that window; the next one starts as normal. A block still running when the window closes gets to finish.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flInkSoft.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Schedules")
                    .font(FLTypography.display)
                    .foregroundStyle(Color.flInk)
                Text(subtitle)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }
            Spacer()
            Button("＋  Add schedule") {
                controller.addSchedule()
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 36))
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
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
        HStack(spacing: 12) {
            Image(systemName: "power")
                .foregroundStyle(Color.flWarning)
            Text("Schedules only run while LockIn is open.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInk)
            Spacer()
            Button("Open LockIn at login") {
                controller.setLaunchAtLogin(true)
            }
            .buttonStyle(FLLinkButtonStyle())
        }
        .padding(12)
        .background(Color.flWarning.opacity(0.1), in: RoundedRectangle(cornerRadius: FLRadius.lg))
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
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
                    .flField(width: 180)

                Spacer()

                if controller.activeScheduleOccurrence?.schedule.id == schedule.id {
                    FLBadge(text: "On now")
                }

                Toggle("", isOn: binding(\.isEnabled))
                    .toggleStyle(.switch)
                    .tint(Color.flAccentDeep)
                    .labelsHidden()
                    .accessibilityLabel("Enable \(schedule.name)")

                Button {
                    controller.requestRemoveSchedule(schedule)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.flClay)
                }
                .buttonStyle(.plain)
                .help("Delete \(schedule.name)")
                .accessibilityLabel("Delete \(schedule.name)")
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

            HStack(alignment: .top, spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strict blocks")
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInk)
                    Text("No ending, skipping, or quitting during this schedule's focus blocks.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }
                Spacer(minLength: FLSpacing.md)
                Toggle("", isOn: binding(\.strict))
                    .toggleStyle(.switch)
                    .tint(Color.flAccentDeep)
                    .labelsHidden()
                    .accessibilityLabel("Strict blocks for \(schedule.name)")
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
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
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.flCanvas : Color.flInkSoft)
                .frame(width: 44, height: 26)
                .background(Capsule().fill(isOn ? Color.flAccentDeep : Color.flCanvasWarm))
                .overlay(Capsule().strokeBorder(isOn ? .clear : Color.flHairline, lineWidth: 1))
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
