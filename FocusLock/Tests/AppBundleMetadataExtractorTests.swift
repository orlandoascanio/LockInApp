import FocusLockCore
import XCTest

final class AppBundleMetadataExtractorTests: XCTestCase {
    func testExtractsBlockedAppFromApplicationBundle() throws {
        let appURL = try makeApplicationBundle(
            name: "Example",
            displayName: "Example App",
            bundleName: "Example",
            bundleIdentifier: "com.example.app"
        )

        let result = AppBundleMetadataExtractor.extractBlockedApp(from: appURL)

        switch result {
        case .success(let app):
            XCTAssertEqual(app.name, "Example App")
            XCTAssertEqual(app.bundleId, "com.example.app")
        case .failure(let error):
            XCTFail("Expected metadata extraction to succeed, got \(error)")
        }
    }

    func testRejectsNonApplicationBundleURL() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("NotAnApp.txt")
        try Data("nope".utf8).write(to: url)

        let result = AppBundleMetadataExtractor.extractBlockedApp(from: url)

        switch result {
        case .success:
            XCTFail("Expected non-.app URL to be rejected")
        case .failure(let error):
            XCTAssertEqual(error, .notApplicationBundle)
        }
    }

    func testRejectsAppBundleWithMissingBundleIdentifier() throws {
        let appURL = try makeApplicationBundle(
            name: "MissingId",
            displayName: "Missing ID",
            bundleName: "Missing ID",
            bundleIdentifier: nil
        )

        let result = AppBundleMetadataExtractor.extractBlockedApp(from: appURL)

        switch result {
        case .success:
            XCTFail("Expected missing bundle identifier to be rejected")
        case .failure(let error):
            XCTAssertEqual(error, .missingBundleIdentifier)
        }
    }

    private func makeApplicationBundle(
        name: String,
        displayName: String?,
        bundleName: String?,
        bundleIdentifier: String?
    ) throws -> URL {
        let directory = try temporaryDirectory()
        let appURL = directory.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        var plist: [String: Any] = [
            "CFBundleExecutable": name,
            "CFBundlePackageType": "APPL"
        ]

        if let displayName {
            plist["CFBundleDisplayName"] = displayName
        }

        if let bundleName {
            plist["CFBundleName"] = bundleName
        }

        if let bundleIdentifier {
            plist["CFBundleIdentifier"] = bundleIdentifier
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return appURL
    }
}
