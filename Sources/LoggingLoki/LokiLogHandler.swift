import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

public struct LokiLogHandler: LogHandler {

    internal let session: LokiSession

    private var lokiURL: URL

    public var label: String

    internal init(label: String, lokiURL: URL, session: LokiSession) {
        self.label = label
        #if os(Linux)
        self.lokiURL = lokiURL.appendingPathComponent("/loki/api/v1/push")
        #else
        if #available(macOS 13.0, *) {
            self.lokiURL = lokiURL.appending(path: "/loki/api/v1/push")
        } else {
            self.lokiURL = lokiURL.appendingPathComponent("/loki/api/v1/push")
        }
        #endif
        self.session = session
    }

    public init(label: String, lokiURL: URL) {
        self.label = label
        #if os(Linux)
        self.lokiURL = lokiURL.appendingPathComponent("/loki/api/v1/push")
        #else
        if #available(macOS 13.0, *) {
            self.lokiURL = lokiURL.appending(path: "/loki/api/v1/push")
        } else {
            self.lokiURL = lokiURL.appendingPathComponent("/loki/api/v1/push")
        }
        #endif
        self.session = URLSession(configuration: .ephemeral)
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true ? prettyMetadata : prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))


        let labels: [String: String] = ["service": label, "source": source, "file": file, "function": function, "line": String(line)]
        let timestamp = Date()
        let message = "[\(level.rawValue.uppercased())]\(prettyMetadata.map { " \($0)"} ?? "") \(message)"

        session.send((timestamp, message), with: labels, url: lokiURL) { result in
            if case .failure(let failure) = result {
                debugPrint(failure)
            }
        }
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            prettyMetadata = prettify(metadata)
        }
    }

    public var logLevel: Logger.Level = .info

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }


}
