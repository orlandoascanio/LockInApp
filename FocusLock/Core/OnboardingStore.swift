import Foundation

public final class OnboardingStore {
    public let url: URL

    public init(baseDirectory: URL) {
        url = baseDirectory.appendingPathComponent("onboarding-progress.json")
    }

    public func load(isNewInstall: Bool, now: Date = Date()) -> OnboardingProgress {
        if let data = try? Data(contentsOf: url),
           let progress = try? FocusLockJSONCoding.decoder.decode(OnboardingProgress.self, from: data) {
            return progress
        }
        // Preserve an unreadable baseline, and never count it as a fresh user.
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("invalid-\(UUID().uuidString)")
            try? FileManager.default.copyItem(at: url, to: backup)
            return OnboardingProgress(isNewInstall: false, now: now)
        }
        return OnboardingProgress(isNewInstall: isNewInstall, now: now)
    }

    public func save(_ progress: OnboardingProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FocusLockJSONCoding.encoder.encode(progress).write(to: url, options: .atomic)
    }
}
