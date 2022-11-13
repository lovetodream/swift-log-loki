import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

protocol LokiSession {
    func send(_ logs: [LokiLog], with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ())

    func send(_ log: LokiLog, with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ())
}

extension LokiSession {
    func send(_ log: LokiLog, with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ()) {
        send([log], with: labels, url: url, completion: completion)
    }
}

extension URLSession: LokiSession {
    func send(_ logs: [LokiLog], with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ()) {
        do {
//            let data = try JSONEncoder().encode(LokiRequest(streams: [.init(logs, with: labels)]))

            let proto = Logproto_PushRequest.with { request in
                request.streams = [
                    .with { stream in
                        stream.labels = "{" + labels.map { "\($0)=\($1)" }.joined(separator: ",") + "}"
                        stream.entries = logs.map { timestamp, message in
                            Logproto_EntryAdapter.with { entry in
                                entry.timestamp = .with {
                                    $0.seconds = Int64(timestamp.timeIntervalSince1970.rounded(.down))
                                    $0.nanos = Int32(timestamp.timeIntervalSince1970 * 1_000_000_000) % 1_000_000_000
                                }
                                entry.line = message
                            }
                        }
                    }
                ]
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try proto.serializedData()
            request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")

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
