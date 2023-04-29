import Foundation
import Logging

struct ConsoleStyle {
	
	var prefix: String
}

extension String {
	
	func consoleStyle(_ style: ConsoleStyle) -> String {
		"\(style.prefix)\(self)\u{001B}[0m"
	}
}

extension Logger.Level {
	
	/// Converts log level to console style
	var style: ConsoleStyle {
		switch self {
		case .trace: return ConsoleStyle(prefix: "\u{001B}[96m")
		case .debug: return ConsoleStyle(prefix: "\u{001B}[94m")
		case .info, .notice: return ConsoleStyle(prefix: "\u{001B}[32m")
		case .warning: return ConsoleStyle(prefix: "\u{001B}[33m")
		case .error: return ConsoleStyle(prefix: "\u{001B}[91m")
		case .critical: return ConsoleStyle(prefix: "\u{001B}[95m")
		}
	}
}
