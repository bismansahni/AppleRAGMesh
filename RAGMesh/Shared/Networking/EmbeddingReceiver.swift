//
//  EmbeddingReceiver.swift
//  RAGMesh
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation
import MultipeerConnectivity

class EmbeddingReceiver {
    private let session: MCSession
    private let semaphore: DispatchSemaphore
    private let maxConcurrentChunks = 2

    private var collectedChunks: [[String: Any]] = []

    var currentQuestion: String = ""

    init(session: MCSession) {
        self.session = session
        self.semaphore = DispatchSemaphore(value: maxConcurrentChunks)
    }

    private func handleRetrievalResult(json: [String: Any]) {
        guard let results = json["results"] as? [[String: Any]] else {
            print("❌ [Mac] Invalid or missing results in retrievalresult message")
            return
        }

        print("📥 [Mac] Received retrieval results from peer")
        collectedChunks.append(contentsOf: results)

        if collectedChunks.count >= 3 {
            let topChunks = collectedChunks
                .sorted { ($0["score"] as? Double ?? -1.0) > ($1["score"] as? Double ?? -1.0) }
                .prefix(3)

            print("🏆 Final Top 3 Chunks:")
            for (index, result) in topChunks.enumerated() {
                let file = result["file"] as? String ?? "Unknown"
                let chunkIndex = result["chunkIndex"] as? Int ?? -1
                let text = result["text"] as? String ?? ""
                let device = result["device"] as? String ?? "Unknown"
                let score = result["score"] as? Double ?? -1.0

                print("""
                🔹 Final Top \(index + 1):
                📄 File: \(file)
                🔢 Chunk Index: \(chunkIndex)
                📃 Snippet: \(text.prefix(100))...
                💻 Source Device: \(device)
                🧠 Score: \(score)
                """)
            }

            let context = topChunks.map {
                let file = $0["file"] as? String ?? "Unknown"
                let chunkIndex = $0["chunkIndex"] as? Int ?? -1
                let device = $0["device"] as? String ?? "Unknown"
                let text = $0["text"] as? String ?? ""
                return "[\(file) — Chunk \(chunkIndex) — \(device)]\n\(text)"
            }.joined(separator: "\n\n")

            let sourceSummary = topChunks.map {
                "\($0["file"] ?? "Unknown") [\($0["chunkIndex"] ?? -1)] from \($0["device"] ?? "Unknown")]"
            }.joined(separator: ", ")

            Task {
                await runGeneration(
                    with: context,
                    question: currentQuestion,
                    sourceSummary: sourceSummary
                ) { answer in
                    print("🧠 Final Answer:\n\(answer)")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .didReceiveFinalAnswer,
                            object: answer
                        )
                    }
                }
            }

            collectedChunks.removeAll()
        }
    }

    private func handleInitialFileEmbedding(json: [String: Any], fromPeer: MCPeerID) {
        guard let fileName = json["fileName"] as? String,
              let text = json["text"] as? String else {
            print("❌ [Mac] Missing fileName or text in embedding request")
            return
        }

        print("📥 [Mac] Received file for embedding: \(fileName)")
        print("📄 Full text length: \(text.count) characters")
        print("📝 [Mac] Full file context for \(fileName):\n\(text)\n")

        Task.detached(priority: .userInitiated) {
            self.semaphore.wait()
            defer { self.semaphore.signal() }

            let device = json["device"] as? String ?? fromPeer.displayName
            let embeddedChunks = await MiniLMEmbedder.embedReturningChunks(text: text, filePath: fileName)

            for embedded in embeddedChunks {
                print("📤 [Mac] Sending embedded chunk \(embedded.chunkIndex) of \(fileName)")

                let response: [String: Any] = [
                    "type": "initialembeddingresult",
                    "fileName": fileName,
                    "chunkIndex": embedded.chunkIndex,
                    "text": embedded.text,
                    "embedding": embedded.embedding,
                    "device": device
                ]

                do {
                    let data = try JSONSerialization.data(withJSONObject: response)
                    try self.session.send(data, toPeers: [fromPeer], with: .reliable)
                } catch {
                    print("❌ [Mac] Failed to send embedded chunk \(embedded.chunkIndex): \(error)")
                }
            }
        }
    }
}

// MARK: - Conform to MessageHandlingDelegate

extension EmbeddingReceiver: MessageHandlingDelegate {
    func handleInitialFileEmbedding(_ data: [String: Any], from peer: MCPeerID) {
        handleInitialFileEmbedding(json: data, fromPeer: peer)
    }

    func handleInitialEmbeddingResult(_ data: [String: Any], from peer: MCPeerID) {
        // Mac doesn't handle this
    }

    func handleQueryEmbedding(_ data: [String: Any], from peer: MCPeerID) {
        // Mac doesn't handle this
    }

    func handleRetrievalResult(_ data: [String: Any], from peer: MCPeerID) {
        handleRetrievalResult(json: data)
    }
}
