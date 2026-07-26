import Foundation

public struct CopilotHookInstallationStatus: Equatable, Sendable {
    public var copilotDirectory: URL
    public var hooksDirectory: URL
    public var hooksURL: URL
    public var manifestURL: URL
    public var hooksBinaryURL: URL?
    public var managedHooksPresent: Bool
    public var manifest: CopilotHookInstallerManifest?

    public init(
        copilotDirectory: URL,
        hooksDirectory: URL,
        hooksURL: URL,
        manifestURL: URL,
        hooksBinaryURL: URL?,
        managedHooksPresent: Bool,
        manifest: CopilotHookInstallerManifest?
    ) {
        self.copilotDirectory = copilotDirectory
        self.hooksDirectory = hooksDirectory
        self.hooksURL = hooksURL
        self.manifestURL = manifestURL
        self.hooksBinaryURL = hooksBinaryURL
        self.managedHooksPresent = managedHooksPresent
        self.manifest = manifest
    }
}

public final class CopilotHookInstallationManager: @unchecked Sendable {
    public let copilotDirectory: URL
    public let managedHooksBinaryURL: URL
    private let fileManager: FileManager

    public init(
        copilotDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".copilot", isDirectory: true),
        managedHooksBinaryURL: URL = ManagedHooksBinary.defaultURL(),
        fileManager: FileManager = .default
    ) {
        self.copilotDirectory = copilotDirectory
        self.managedHooksBinaryURL = managedHooksBinaryURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public func status(hooksBinaryURL: URL? = nil) throws -> CopilotHookInstallationStatus {
        let hooksDirectory = copilotDirectory.appendingPathComponent("hooks", isDirectory: true)
        let hooksURL = hooksDirectory.appendingPathComponent(CopilotHookInstaller.managedHookFileName)
        let manifestURL = copilotDirectory.appendingPathComponent(CopilotHookInstallerManifest.fileName)
        let resolvedBinaryURL = resolvedHooksBinaryURL(explicitURL: hooksBinaryURL)
        let manifest = try loadManifest(at: manifestURL)
        let managedCommand = manifest?.hookCommand ?? resolvedBinaryURL.map { CopilotHookInstaller.hookCommand(for: $0.path) }
        let contents = try? Data(contentsOf: hooksURL)
        let managedHooksPresent = contents.flatMap { data -> Bool? in
            guard let command = managedCommand,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            return String(describing: object).contains(command)
        } ?? false

        return CopilotHookInstallationStatus(
            copilotDirectory: copilotDirectory,
            hooksDirectory: hooksDirectory,
            hooksURL: hooksURL,
            manifestURL: manifestURL,
            hooksBinaryURL: resolvedBinaryURL,
            managedHooksPresent: managedHooksPresent,
            manifest: manifest
        )
    }

    @discardableResult
    public func install(hooksBinaryURL: URL) throws -> CopilotHookInstallationStatus {
        let hooksDirectory = copilotDirectory.appendingPathComponent("hooks", isDirectory: true)
        try fileManager.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)

        let hooksURL = hooksDirectory.appendingPathComponent(CopilotHookInstaller.managedHookFileName)
        let manifestURL = copilotDirectory.appendingPathComponent(CopilotHookInstallerManifest.fileName)
        let installedBinaryURL = try ManagedHooksBinary.install(
            from: hooksBinaryURL,
            to: managedHooksBinaryURL,
            fileManager: fileManager
        )
        let command = CopilotHookInstaller.hookCommand(for: installedBinaryURL.path)
        let hooksJSON = try CopilotHookInstaller.hooksJSON(hookCommand: command)

        if fileManager.fileExists(atPath: hooksURL.path) {
            try backupFile(at: hooksURL)
        }
        try hooksJSON.write(to: hooksURL, options: .atomic)

        let manifest = CopilotHookInstallerManifest(hookCommand: command)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        return try status(hooksBinaryURL: installedBinaryURL)
    }

    @discardableResult
    public func uninstall() throws -> CopilotHookInstallationStatus {
        let hooksDirectory = copilotDirectory.appendingPathComponent("hooks", isDirectory: true)
        let hooksURL = hooksDirectory.appendingPathComponent(CopilotHookInstaller.managedHookFileName)
        let manifestURL = copilotDirectory.appendingPathComponent(CopilotHookInstallerManifest.fileName)

        if fileManager.fileExists(atPath: hooksURL.path) {
            try fileManager.removeItem(at: hooksURL)
        }
        if fileManager.fileExists(atPath: manifestURL.path) {
            try fileManager.removeItem(at: manifestURL)
        }

        return try status()
    }

    private func loadManifest(at url: URL) throws -> CopilotHookInstallerManifest? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CopilotHookInstallerManifest.self, from: data)
    }

    private func resolvedHooksBinaryURL(explicitURL: URL?) -> URL? {
        if let explicitURL {
            return explicitURL.standardizedFileURL
        }
        guard fileManager.isExecutableFile(atPath: managedHooksBinaryURL.path) else {
            return nil
        }
        return managedHooksBinaryURL
    }

    private func backupFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.appendingPathExtension("backup.\(timestamp)")
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: url, to: backupURL)
    }
}
