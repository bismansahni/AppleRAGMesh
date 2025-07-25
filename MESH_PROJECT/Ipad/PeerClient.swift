



import Foundation
import MultipeerConnectivity
import UIKit

class PeerClient: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {

    private let serviceType = "rag-service"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    override init() {
        super.init()

        peerID = MCPeerID(displayName: UIDevice.current.name)
        print("🟢 [iPhone] Initializing PeerClient with peerID: \(peerID.displayName)")

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        print("📡 [iPhone] Started advertising with serviceType: \(serviceType)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📥 [iPhone] Received invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let stateString = ["notConnected", "connecting", "connected"][state.rawValue]
        print("📶 [iPhone] Session state changed: \(peerID.displayName) -> \(stateString)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "initialembeddingresult":
                    guard let fileName = json["fileName"] as? String,
                          let chunkIndex = json["chunkIndex"] as? Int,
                          let chunkText = json["text"] as? String,
                          let rawEmbedding = json["embedding"] as? [NSNumber] else {
                        print("⚠️ [iPhone] Malformed embedding result: \(json)")
                        return
                    }

                    let embeddingArray = rawEmbedding.map { $0.floatValue }
                    let sourceDevice = json["device"] as? String ?? peerID.displayName

                    print("""
                    ✅ [iPhone] Received embedding for chunk \(chunkIndex) of file: \(fileName)
                    📦 Full Response:
                    - Chunk Index: \(chunkIndex)
                    - Text: \"\(chunkText.prefix(100))...\"
                    - Embedding Dim: \(embeddingArray.count)
                    - Device: \(sourceDevice)
                    """)
                    
                    
                    print("📝 [iPad] Full chunk text for \(fileName) [chunk \(chunkIndex)]:\n\(chunkText)\n")

                    DispatchQueue.global(qos: .utility).async {
                        StorageUtility.shared.saveChunk(
                            file: fileName,
                            chunkIndex: chunkIndex,
                            text: chunkText,
                            embedding: embeddingArray,
                            device: UIDevice.current.name
                        )
                    }

                case "queryembedding":
                    guard let rawEmbedding = json["embedding"] as? [NSNumber] else {
                        print("⚠️ [iPhone] Malformed queryembedding request")
                        return
                    }

                    let embedding = rawEmbedding.map { $0.floatValue }
                    let question = json["question"] as? String ?? ""
                    print("🧠 [iPhone] Received embedding vector (dim: \(embedding.count))")
                    print("❓ [iPhone] Original question: \(question)")

                    DispatchQueue.global(qos: .userInitiated).async {
                        let results = StorageUtility.shared.retrieve(queryEmbedding: embedding)
                        print("🔍 Top results from vector search: \(results.prefix(3))")

                        guard let peer = self.session.connectedPeers.first else {
                            print("⚠️ [iPhone] No connected peer to send results to")
                            return
                        }

                        let topChunks = results.prefix(5).map { entry in
                            let chunk = entry.chunk
                            return [
                                "file": chunk.file,
                                "chunkIndex": chunk.chunkIndex,
                                "text": chunk.text,
                                "device": chunk.device,
                                "score": entry.score
                            ]
                        }

                        let response: [String: Any] = [
                            "type": "retrievalresult",
                            "results": topChunks,
                            "question": question
                        ]

                        do {
                            let data = try JSONSerialization.data(withJSONObject: response)
                            try self.session.send(data, toPeers: [peer], with: .reliable)
                            print("📬 [iPhone] Sent retrieval results to Mac")
                        } catch {
                            print("❌ [iPhone] Failed to send retrieval results: \(error)")
                        }
                    }

                default:
                    print("❓ [iPhone] Unknown message type: \(type)")
                }
            } else {
                print("❓ [iPhone] Received unsupported or invalid data")
            }
        } catch {
            print("❌ [iPhone] JSON decode error: \(error)")
        }
    }

    func sendEmbeddingRequestToMac(text: String, fileName: String) async {
        guard let peer = session.connectedPeers.first else {
            browser.stopBrowsingForPeers()
            browser.startBrowsingForPeers()
            print("⚠️ [iPhone] No connected Mac to send data to")
            return
        }

        let message: [String: Any] = [
            "type": "initialfileembedding",
            "fileName": fileName,
            "text": text,
            "device": UIDevice.current.name
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            try session.send(data, toPeers: [peer], with: .reliable)
            print("📤 [iPhone] Sent full file '\(fileName)' to Mac for embedding")
        } catch {
            print("❌ [iPhone] Failed to send embedding request: \(error)")
        }
    }

    // Unused delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
