import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging
import Snappy

protocol LokiSession {
    func send(_ logs: [LokiLog],
              with labels: LokiLabels,
              url: URL,
              sendAsJSON: Bool,
              completion: @escaping (Result<StatusCode, Error>) -> Void)

    func send(_ log: LokiLog,
              with labels: LokiLabels,
              url: URL,
              sendAsJSON: Bool,
              completion: @escaping (Result<StatusCode, Error>) -> Void)
}

extension LokiSession {
    func send(_ log: LokiLog,
              with labels: LokiLabels,
              url: URL,
              sendAsJSON: Bool = false,
              completion: @escaping (Result<StatusCode, Error>) -> Void) {
        send([log], with: labels, url: url, sendAsJSON: sendAsJSON, completion: completion)
    }
}

extension URLSession: LokiSession {
    func send(_ logs: [LokiLog],
              with labels: LokiLabels,
              url: URL,
              sendAsJSON: Bool = false,
              completion: @escaping (Result<StatusCode, Error>) -> Void) {
        do {
            let data: Data
            let contentType: String
            
            if sendAsJSON {
                data = try JSONEncoder().encode(LokiRequest(streams: [.init(logs, with: labels)]))
                contentType = "application/json"
            } else {
                let proto = Logproto_PushRequest.with { request in
                    request.streams = [
                        .with { stream in
                            stream.labels = "{" + labels.map { "\($0)=\($1)" }.joined(separator: ",") + "}"
                            stream.entries = logs.map { timestamp, message in
                                Logproto_EntryAdapter.with { entry in
                                    entry.timestamp = .with {
                                        $0.seconds = Int64(timestamp.timeIntervalSince1970.rounded(.down))
                                        $0.nanos = Int32(Int(timestamp.timeIntervalSince1970 * 1_000_000_000) % 1_000_000_000)
                                    }
                                    entry.line = message
                                }
                            }
                        }
                    ]
                }
                data = try proto.serializedData().compressedUsingSnappy()
                contentType = "application/x-protobuf"
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")

            let task = dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                } else if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                    completion(.success(httpResponse.statusCode))
                } else {
                    completion(.failure(LokiError.invalidResponse))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}
