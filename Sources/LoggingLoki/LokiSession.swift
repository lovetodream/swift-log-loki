import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

protocol LokiSession {
    func send(_ logs: [LokiLog], with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ())

    func send(_ log: LokiLog, with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ())
}

extension URLSession: LokiSession {
    func send(_ logs: [LokiLog], with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ()) {
        do {
            let data = try JSONEncoder().encode(LokiRequest(streams: [.init(logs, with: labels)]))

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

    func send(_ log: LokiLog, with labels: LokiLabels, url: URL, completion: @escaping (Result<StatusCode, Error>) -> ()) {
        send([log], with: labels, url: url, completion: completion)
    }
}
