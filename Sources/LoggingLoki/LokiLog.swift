import struct Foundation.Date
import Logging

struct LokiLog {
    var timestamp: Date
    var level: Logger.Level
    var message: Logger.Message
    var metadata: Logger.Metadata

    struct Transport {
        var timestamp: Date
        var line: String
        var metadata: [String: String]?
    }
}
