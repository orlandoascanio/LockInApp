import Foundation

func temporaryDirectory(named name: String = UUID().uuidString) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FocusLockTests", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
