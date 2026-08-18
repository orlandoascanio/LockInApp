import FocusLockCore
import SwiftUI

/// A keyboard-first duration editor with a stepper for small adjustments.
struct FLDurationField: View {
    let label: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(label: String, minutes: Binding<Int>, range: ClosedRange<Int>) {
        self.label = label
        _minutes = minutes
        self.range = range
        _text = State(initialValue: String(minutes.wrappedValue))
    }

    var body: some View {
        HStack(spacing: FLSpacing.sm) {
            Text(label)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)

            TextField("Duration", text: $text)
                .font(.system(size: 15, design: .serif))
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .focused($isFocused)
                .onSubmit(commit)
                .onExitCommand(perform: cancel)
                .accessibilityLabel("\(label) duration")
                .accessibilityHint("Enter \(range.lowerBound) to \(range.upperBound) minutes")
                .help("\(label): \(range.lowerBound)–\(range.upperBound) minutes")

            Text("min")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)

            Stepper(label, value: stepperMinutes, in: range)
                .labelsHidden()
                .accessibilityLabel("Adjust \(label.lowercased()) duration")
        }
        .onChange(of: isFocused) { focused in
            if !focused {
                commit()
            }
        }
        .onChange(of: text) { newValue in
            let digits = MinuteInput.digitsOnly(newValue)
            if digits != newValue {
                text = digits
                return
            }

            if let parsed = MinuteInput.parseMinutes(digits), range.contains(parsed), parsed != minutes {
                minutes = parsed
            }
        }
        .onChange(of: minutes) { newValue in
            if !isFocused {
                text = String(newValue)
            }
        }
    }

    private var stepperMinutes: Binding<Int> {
        Binding(
            get: { minutes },
            set: { newValue in
                minutes = newValue
                text = String(newValue)
                isFocused = false
            }
        )
    }

    private func commit() {
        guard let parsed = MinuteInput.parseMinutes(text) else {
            cancel()
            return
        }

        let clamped = min(range.upperBound, max(range.lowerBound, parsed))
        minutes = clamped
        text = String(clamped)
        isFocused = false
    }

    private func cancel() {
        text = String(minutes)
        isFocused = false
    }
}
