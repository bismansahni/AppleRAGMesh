


import Foundation
import MultipeerConnectivity
import UIKit

final class PeerClient: NSObject {
    public let sessionManager: PeerSessionManager
    private let messageHandler: MessageHandler
    private let deviceName = UIDevice.current.name

    override init() {
        sessionManager = PeerSessionManager(displayName: deviceName, role: .advertiser)
        messageHandler = MessageHandler(delegate: StorageUtility.shared)
        super.init()

        sessionManager.delegate = self
        print("🟢 [iPhone] PeerClient initialized as advertiser: \(deviceName)")
    }

    func sendEmbeddingRequestToMac(text: String, fileName: String) async {
        let message: [String: Any] = [
            "type": MessageType.initialFileEmbedding.rawValue,
            "fileName": fileName,
            "text": text,
            "device": deviceName
        ]
        sessionManager.send(message)
        print("📤 [iPhone] Sent full file '\(fileName)' to Mac for embedding")
    }
}

// MARK: - PeerSessionDelegate

extension PeerClient: PeerSessionDelegate {
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
