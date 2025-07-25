



import Foundation
import SwiftUI
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published private(set) var logs: [String] = []

    private init() {}

    func append(_ message: String) {
        let timestamp = Self.timestamp()
        DispatchQueue.main.async {
            self.logs.append("[\(timestamp)] \(message)")
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }

    func publisher() -> Published<[String]>.Publisher {
        $logs
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
