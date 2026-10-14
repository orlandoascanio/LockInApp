import AppKit
import XCTest
@testable import FocusLockCore

final class WebsiteGuardRestorationTests: XCTestCase {
    private final class Browser: BrowserScripting {
        struct Tab {
            var browser: SupportedBrowser = .chrome
            var url: String
        }
        var tabs: [Tab] = []
        var selected = 0
        var canRedirect = true
        var canRestore = true
        var beforeRead: (() -> Void)?
        var afterRestore: (() -> Void)?
        var restoreCalls = 0

        func currentURL(in browser: SupportedBrowser) -> Result<URL?, BrowserScriptError> {
            beforeRead?()
            return .success(URL(string: tabs[selected].url))
        }

        func redirect(_ browser: SupportedBrowser, from originalURL: String, to url: String) -> Bool {
            guard canRedirect, tabs[selected].url == originalURL else { return false }
            tabs[selected].url = url
            return true
        }

        func restore(_ browser: SupportedBrowser, matching blockedURL: String, to originalURL: String) -> Bool {
            restoreCalls += 1
            guard canRestore else { return false }
            for index in tabs.indices where tabs[index].browser == browser && tabs[index].url == blockedURL {
                tabs[index].url = originalURL
            }
            afterRestore?()
            return true
        }
    }

    private func check(_ guarder: WebsiteGuard, browser: SupportedBrowser = .chrome) {
        let done = expectation(description: "browser checked")
        guarder.check(frontmostBundleIdentifier: browser.bundleIdentifier) { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    func testEndingFocusRestoresExactURLsInBackgroundTabsAndOtherBrowsers() {
        let browser = Browser()
        let urls = ["https://youtube.com/watch?v=one&t=12#details", "https://youtube.com/watch?v=two", "https://youtube.com/three"]
        browser.tabs = urls.map { Browser.Tab(url: $0) }
        browser.tabs[2].browser = .safari
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        for index in browser.tabs.indices {
            browser.selected = index
            check(guarder, browser: browser.tabs[index].browser)
        }
        XCTAssertEqual(Set(browser.tabs.map(\.url)).count, 3)
        XCTAssertTrue(browser.tabs.allSatisfy { $0.url.hasPrefix("data:") })

        guarder.stop(waitUntilRestored: true)

        XCTAssertEqual(browser.tabs.map(\.url), urls)
        XCTAssertFalse(guarder.isActive)
    }

    func testNavigatingAwayOrClosingATabDoesNotReopenIt() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one"), .init(url: "https://youtube.com/two")]
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        check(guarder)
        browser.selected = 1
        check(guarder)
        browser.tabs.removeLast()
        browser.tabs[0].url = "https://developer.apple.com/"

        guarder.stop(waitUntilRestored: true)

        XCTAssertEqual(browser.tabs.map(\.url), ["https://developer.apple.com/"])
    }

    func testDisablingARuleRestoresOnlySitesNoLongerBlocked() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one"), .init(url: "https://reddit.com/r/all")]
        let guarder = WebsiteGuard(scripting: browser)
        let youtube = BlockedSite(pattern: "youtube.com")
        let reddit = BlockedSite(pattern: "reddit.com")
        guarder.update(sites: [youtube, reddit], endsAt: nil)
        check(guarder)
        browser.selected = 1
        check(guarder)
        var disabled = youtube
        disabled.isEnabled = false

        guarder.update(sites: [disabled, reddit], endsAt: nil)
        check(guarder)

        XCTAssertEqual(browser.tabs[0].url, "https://youtube.com/one")
        XCTAssertTrue(browser.tabs[1].url.hasPrefix("data:"))
        guarder.stop(waitUntilRestored: true)
        XCTAssertEqual(browser.tabs[1].url, "https://reddit.com/r/all")
    }

    func testRemovingAllRulesRestoresTabs() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one")]
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        check(guarder)
        let restored = expectation(description: "removing all rules restores the tab")
        browser.afterRestore = { restored.fulfill() }
        guarder.update(sites: [], endsAt: nil)
        wait(for: [restored], timeout: 5)
        XCTAssertEqual(browser.tabs[0].url, "https://youtube.com/one")
        XCTAssertEqual(browser.restoreCalls, 1)
    }

    func testFailedRestorationCanBeRetriedWithoutRepeatingSuccessfulRestorations() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one")]
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        check(guarder)
        browser.canRestore = false
        guarder.stop(waitUntilRestored: true)
        XCTAssertTrue(browser.tabs[0].url.hasPrefix("data:"))
        browser.canRestore = true
        guarder.stop(waitUntilRestored: true)
        guarder.stop(waitUntilRestored: true)
        XCTAssertEqual(browser.tabs[0].url, "https://youtube.com/one")
        XCTAssertEqual(browser.restoreCalls, 2)
    }

    func testFailedRedirectIsNotTrackedForRestoration() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one")]
        browser.canRedirect = false
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        check(guarder)
        guarder.stop(waitUntilRestored: true)
        XCTAssertEqual(browser.restoreCalls, 0)
    }

    func testStopRestoresARedirectAlreadyInFlightAndSuppressesStaleNotification() {
        let browser = Browser()
        browser.tabs = [.init(url: "https://youtube.com/one")]
        let started = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        browser.beforeRead = {
            started.signal()
            _ = resume.wait(timeout: .now() + 5)
        }
        let guarder = WebsiteGuard(scripting: browser)
        guarder.update(sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)
        guarder.onBlocked = { _ in XCTFail("A completed block must not report a stale interception") }
        let done = expectation(description: "in-flight check completed")
        guarder.check(frontmostBundleIdentifier: SupportedBrowser.chrome.bundleIdentifier) { done.fulfill() }
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        guarder.stop()
        resume.signal()
        guarder.stop(waitUntilRestored: true)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(browser.tabs[0].url, "https://youtube.com/one")
    }

    func testBrowserScriptsCompileAndRestoreWithoutSelectingTabs() {
        for browser in [SupportedBrowser.chrome, .safari] {
            let restore = browser.restoreScript(matching: #"data:text/html;base64,test#quietwhile-123"#, to: #"https://example.com/?q="quoted"&x=\path"#)
            XCTAssertTrue(restore.contains("tabs of browserWindow"))
            XCTAssertFalse(restore.contains("set active tab"))
            XCTAssertFalse(restore.contains("set current tab"))
            // Compiling terminology requires that browser's dictionary.
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil else { continue }
            for source in [restore, browser.redirectScript(from: "https://example.com/", to: "data:text/html,test")] {
                var error: NSDictionary?
                XCTAssertTrue(NSAppleScript(source: source)?.compileAndReturnError(&error) == true, "\(error ?? [:])")
            }
        }
    }
}
