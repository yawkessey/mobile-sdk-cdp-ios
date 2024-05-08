import Foundation
import SFMCSDK

class HelloCDPLogOutputter: LogOutputter {
    var logMessages: [String] = []

    static let shared = HelloCDPLogOutputter()
    
    override func out(level: LogLevel, subsystem: String, category: LoggerCategory, message: String) {
        logMessages.append(message)
        print(subsystem, category.rawValue, message)
    }
}
