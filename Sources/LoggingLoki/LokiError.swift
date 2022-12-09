import struct Foundation.Data
import protocol Foundation.LocalizedError

enum LokiError: LocalizedError {
    
    case invalidResponse(Data?)
    case invalidAuthString

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let data):
            guard let data else { return nil }
            return String(data: data, encoding: .utf8)
        case .invalidAuthString:
            return "Invalid Authorization header"
        }
    }
}
