import Foundation

public enum FocusLockLog {
    public static func debug(_ message: String) {
        NSLog("[LockIn] %@", message)
    }
}
