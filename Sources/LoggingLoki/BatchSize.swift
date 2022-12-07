/// Size of a single batch in bytes or log entries.
///
/// Once this threshold is exceeded the batch will be sent to Loki and a new batch will be created.
public enum BatchSize {
    case entries(amount: Int)
    case bytes(amount: Int)
}
