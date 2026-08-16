public enum MinuteInput {
    public static func digitsOnly(_ input: String) -> String {
        input.filter { "0123456789".contains($0) }
    }

    public static func parseMinutes(_ input: String) -> Int? {
        guard !input.isEmpty,
              input == digitsOnly(input),
              let minutes = Int(input)
        else {
            return nil
        }

        return minutes
    }
}
