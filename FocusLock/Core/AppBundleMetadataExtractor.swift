import Foundation

public enum AppBundleMetadataError: LocalizedError, Equatable {
    case notApplicationBundle
    case unreadableBundle
    case missingBundleIdentifier

    public var errorDescription: String? {
        switch self {
        case .notApplicationBundle:
            return "Please choose a macOS .app bundle."
        case .unreadableBundle:
            return "\(AppIdentity.name) could not read that app bundle."
        case .missingBundleIdentifier:
            return "Could not read this app's bundle identifier."
        }
    }
}

public enum AppBundleMetadataExtractor {
    public static func extractBlockedApp(from selectedURL: URL) -> Result<BlockedApp, AppBundleMetadataError> {
        guard selectedURL.pathExtension.lowercased() == "app" else {
            return .failure(.notApplicationBundle)
        }

        guard let bundle = Bundle(url: selectedURL) else {
            return .failure(.unreadableBundle)
        }

        guard let bundleId = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleId.isEmpty else {
            return .failure(.missingBundleIdentifier)
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallbackName = selectedURL.deletingPathExtension().lastPathComponent
        let name = displayName?.nilIfBlank ?? bundleName?.nilIfBlank ?? fallbackName

        return .success(BlockedApp(name: name, bundleId: bundleId))
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
