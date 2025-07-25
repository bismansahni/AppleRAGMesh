
import Foundation
import MultipeerConnectivity

class Broadcaster: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    
//    private var receiver: EmbeddingReceiver!
    
    
    var receiver: EmbeddingReceiver!


    

    private let serviceType = "rag-service"
    private let peerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    private var connectedPeers: [MCPeerID] = []

    override init() {
        super.init()

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        receiver = EmbeddingReceiver(session: session)

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        print("🔍 Broadcaster (Browser) started on Mac: \(peerID.displayName)")
    }

    



    
    func broadcastEmbeddingQuery(vector: [Float]) {
        let payload: [String: Any] = [
            "type": "queryembedding",
            "embedding": vector,
            "question": receiver.currentQuestion
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload)

            let peers = session.connectedPeers
            guard !peers.isEmpty else {
                print("⚠️ No connected peers to send query embedding.")
                return
            }

            try session.send(data, toPeers: peers, with: .reliable)
            print("📤 [Mac] Sent query embedding to iPhone ✅")
        } catch {
            print("❌ Failed to send query embedding: \(error)")
        }
    }


    // MARK: - Browser Delegate

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("📡 Found iPhone peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("⚠️ Lost peer: \(peerID.displayName)")
    }

    // MARK: - Session Delegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("✅ Connected to \(peerID.displayName)")
            if !connectedPeers.contains(peerID) {
                connectedPeers.append(peerID)
            }
        case .connecting:
            print("⏳ Connecting to \(peerID.displayName)...")
        case .notConnected:
            print("❌ Disconnected from \(peerID.displayName)")
            connectedPeers.removeAll { $0 == peerID }
        @unknown default:
            break
        }
    }


    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receiver.handleIncomingData(data, from: peerID)
    }


    // Unused required stubs
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}


 


