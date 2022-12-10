import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LokiAuth {
    
    private let updateRequest: (inout URLRequest) throws -> Void
    
    public init(updateRequest: @escaping (inout URLRequest) throws -> Void) {
        self.updateRequest = updateRequest
    }
    
    public func setAuth(for request: inout URLRequest) throws {
        try updateRequest(&request)
    }
}

public extension LokiAuth {
    
    static var none: LokiAuth {
        LokiAuth { _ in }
    }
    
    ///   - user: client supplied Grafana Loki user name
    ///   - password: client supplied Grafana Loki user password
    static func basic(
        user: String,
        password: String
    ) -> LokiAuth {
        let string = Data("\(user):\(password)".utf8).base64EncodedString()
        return .authHeader {
            "Basic \(string)"
        }
    }
}

private extension LokiAuth {
    
    static func authHeader(_ value: @escaping () throws -> String) -> LokiAuth {
        LokiAuth {
            try $0.setValue(value(), forHTTPHeaderField: "Authorization")
        }
    }
}
