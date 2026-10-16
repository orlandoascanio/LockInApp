import Foundation
import FocusLockCore

/// Reads which website the front browser tab is on, for Insights' focus time.
///
/// Only ever asked about a browser Quietwhile already has permission to read
/// for guarding, so it never puts up a macOS dialog of its own. Keeps the
/// host and nothing else.
final class BrowserDomainSampler {
    private let scripting: BrowserScripting
    private let queue = DispatchQueue(label: "com.lockin.focus-time-sampler")
    private var isSampling = false

    init(scripting: BrowserScripting = AppleScriptBrowserScripting()) {
        self.scripting = scripting
    }

    /// Calls back on the main thread with the host, or `nil` when there is
    /// no page or the browser would not say.
    func host(in browser: SupportedBrowser, completion: @escaping (String?) -> Void) {
        guard !isSampling else { return }
        isSampling = true
        queue.async { [scripting] in
            let host: String?
            if case .success(let url) = scripting.currentURL(in: browser), let scheme = url?.scheme, ["http", "https"].contains(scheme) {
                host = url?.host
            } else {
                host = nil
            }
            DispatchQueue.main.async {
                self.isSampling = false
                completion(host)
            }
        }
    }
}
