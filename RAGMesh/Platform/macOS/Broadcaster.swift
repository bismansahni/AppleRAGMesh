import Foundation
import MultipeerConnectivity
import SwiftUI

class Broadcaster: NSObject, ObservableObject {
    private let sessionManager: PeerSessionManager
    private let messageHandler: MessageHandler
    private let embeddingReceiver: EmbeddingReceiver

    @Published var currentQuestion: String = ""

    override init() {
        let deviceName = Host.current().localizedName ?? "Mac"
        sessionManager = PeerSessionManager(displayName: deviceName, role: .browser)

        embeddingReceiver = EmbeddingReceiver(session: sessionManager.session)
        messageHandler = MessageHandler(delegate: embeddingReceiver)


        super.init()
        sessionManager.delegate = self

    }

    func broadcastEmbeddingQuery(vector: [Float]) {
        let payload: [String: Any] = [
            "type": MessageType.queryEmbedding.rawValue,
            "embedding": vector,
            "question": currentQuestion
        ]
        sessionManager.send(payload)
        print("📤 [Mac] Sent query embedding to iPhone ✅")
    }
}

// MARK: - PeerSessionDelegate

extension Broadcaster: PeerSessionDelegate {
    func didReceiveMessage(_ message: [String: Any], from peer: MCPeerID) {
        messageHandler.handle(message, from: peer)
    }

    func didChangeState(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected: print("✅ Connected to \(peer.displayName)")
        case .connecting: print("⏳ Connecting to \(peer.displayName)...")
        case .notConnected: print("❌ Disconnected from \(peer.displayName)")
        @unknown default: break
        }
    }
}
