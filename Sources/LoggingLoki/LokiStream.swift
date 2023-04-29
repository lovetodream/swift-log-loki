import class Foundation.NumberFormatter
import class Foundation.NSNumber

struct LokiStream: Encodable {
    var stream: Dictionary<String, String>
    var values: Array<Array<String>>

    init(_ logs: [LokiLog], with labels: LokiLabels) {
        self.stream = labels
        self.values = logs.compactMap { log in
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ""
            #if TARGET_OS_OSX
            formatter.thousandSeparator = ""
            #endif
            let timestamp = Int64(log.timestamp.timeIntervalSince1970 * 1_000_000_000) as NSNumber
            guard let formattedTimestamp = formatter.string(from: timestamp) else {
                return nil
            }
            return [formattedTimestamp, log.message]
        }
    }
}
