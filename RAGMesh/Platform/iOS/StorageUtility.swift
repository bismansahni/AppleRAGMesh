import Foundation
import SQLite
import SwiftFaiss
import MultipeerConnectivity

final class StorageUtility: MessageHandlingDelegate {
    static let shared = StorageUtility()

    private let db: Connection
    private let chunks: Table
    private let id = Expression<Int64>("id")
    private let file = Expression<String>("file")
    private let chunkIndex = Expression<Int>("chunk_index")
    private let text = Expression<String>("text")
    private let embedding = Expression<Blob>("embedding")
    private let device = Expression<String>("device")
    private let faissId = Expression<Int>("faiss_id")

    private var faissIndex: FlatIndex?
    private var embeddingDim: Int = 0
    private var _faissID: Int32 = 0
    private let faissIdQueue = DispatchQueue(label: "faiss-id-queue")

    private init() {
        let dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("mesh-rag.sqlite")
        db = try! Connection(dbURL.path)

        chunks = Table("chunks")
        try! db.run(chunks.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(file)
            t.column(chunkIndex)
            t.column(text)
            t.column(embedding)
            t.column(device)
            t.column(faissId)
        })
    }

    // MARK: - MessageHandlingDelegate

    func handleInitialFileEmbedding(_ data: [String: Any], from peer: MCPeerID) {
        // iPhone never receives this
    }

    func handleInitialEmbeddingResult(_ data: [String: Any], from peer: MCPeerID) {
        guard let fileName = data["fileName"] as? String,
              let chunkIndex = data["chunkIndex"] as? Int,
              let chunkText = data["text"] as? String,
              let rawEmbedding = data["embedding"] as? [NSNumber] else {
            print("⚠️ [iPhone] Malformed embedding result")
            return
        }

        let embeddingArray = rawEmbedding.map { $0.floatValue }
        let sourceDevice = data["device"] as? String ?? peer.displayName

        print("📥 [iPhone] Received chunk \(chunkIndex) of \(fileName)")

        DispatchQueue.global(qos: .utility).async {
            self.saveChunk(
                file: fileName,
                chunkIndex: chunkIndex,
                text: chunkText,
                embedding: embeddingArray,
                device: sourceDevice
            )
        }
    }

    func handleQueryEmbedding(_ data: [String: Any], from peer: MCPeerID) {
        guard let rawEmbedding = data["embedding"] as? [NSNumber] else {
            print("⚠️ [iPhone] Malformed query embedding")
            return
        }

        let embedding = rawEmbedding.map { $0.floatValue }
        let question = data["question"] as? String ?? ""

        DispatchQueue.global(qos: .userInitiated).async {
            let results = self.retrieve(queryEmbedding: embedding)
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
                "type": MessageType.retrievalResult.rawValue,
                "results": topChunks,
                "question": question
            ]

            PeerClient().sessionManager.send(response) 
        }
    }

    func handleRetrievalResult(_ data: [String: Any], from peer: MCPeerID) {
        // iPhone doesn't receive this
    }

    // MARK: - Embedding Storage

    private func saveChunk(file: String, chunkIndex: Int, text: String, embedding: [Float], device: String) {
        guard !embedding.isEmpty else { return }

        let currentFaissID = getNextFaissID()

        do {
            let data = Data(buffer: UnsafeBufferPointer(start: embedding, count: embedding.count))
            let blob = Blob(bytes: [UInt8](data))

            let insert = chunks.insert(
                self.file <- file,
                self.chunkIndex <- chunkIndex,
                self.text <- text,
                self.embedding <- blob,
                self.device <- device,
                self.faissId <- Int(currentFaissID)
            )
            try db.run(insert)

            initializeFaissIfNeeded(dimension: embedding.count)
            try faissIndex?.add([embedding])
        } catch {
            print("❌ Failed to store embedding: \(error)")
        }
    }

    private func retrieve(queryEmbedding: [Float], topK: Int = 3) -> [(chunk: ChunkRecord, score: Float)] {
        guard let faissIndex else { return [] }

        do {
            let result = try faissIndex.search([queryEmbedding], k: topK)
            let labels = result.labels.first ?? []
            let distances = result.distances.first ?? []

            var output: [(ChunkRecord, Float)] = []

            for (label, distance) in zip(labels, distances) {
                if label < 0 { continue }
                if let row = try db.pluck(chunks.filter(faissId == Int(label))) {
                    let blob = row[embedding]
                    let floatArray: [Float] = Data(blob.bytes).withUnsafeBytes {
                        Array($0.bindMemory(to: Float.self))
                    }

                    let chunk = ChunkRecord(
                        id: row[id],
                        file: row[file],
                        chunkIndex: row[chunkIndex],
                        text: row[text],
                        embedding: floatArray,
                        device: row[device]
                    )
                    output.append((chunk, distance))
                }
            }

            return output
        } catch {
            print("❌ Retrieval error: \(error)")
            return []
        }
    }

    private func initializeFaissIfNeeded(dimension: Int) {
        if faissIndex == nil {
            faissIndex = try? FlatIndex(d: dimension, metricType: .l2)
            embeddingDim = dimension
        }
    }

    private func getNextFaissID() -> Int32 {
        return faissIdQueue.sync {
            let next = _faissID
            _faissID += 1
            return next
        }
    }
}
