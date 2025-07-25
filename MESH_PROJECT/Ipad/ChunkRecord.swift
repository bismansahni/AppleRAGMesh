

import Foundation
import SQLite
import SwiftFaiss

struct ChunkRecord {
    let id: Int64?
    let file: String
    let chunkIndex: Int
    let text: String
    let embedding: [Float]
    let device: String
}

class StorageUtility {
    static let shared = StorageUtility()

    // SQLite
    private let db: Connection
    private let chunks: Table
    private let id = Expression<Int64>("id")
    private let file = Expression<String>("file")
    private let chunkIndex = Expression<Int>("chunk_index")
    private let text = Expression<String>("text")
    private let embedding = Expression<Blob>("embedding")
    private let device = Expression<String>("device")
    private let faissId = Expression<Int>("faiss_id")

    // Faiss
    private var faissIndex: FlatIndex?
    private var embeddingDim: Int = 0

    // 🔐 Thread-safe Faiss ID tracking
    private var _faissID: Int32 = 0
    private let faissIdQueue = DispatchQueue(label: "faiss-id-queue")

    private init() {
        // Setup SQLite
        let dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("meshrag.sqlite")
        db = try! Connection(dbURL.path)
        print(dbURL.path())

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

    private func initializeFaissIfNeeded(dimension: Int) {
        if faissIndex == nil {
            do {
                faissIndex = try FlatIndex(d: dimension, metricType: .l2)
                embeddingDim = dimension
                print("🧠 Initialized Faiss index with dimension \(dimension)")
            } catch {
                print("❌ Failed to initialize Faiss index: \(error)")
            }
        }
    }

    private func getNextFaissID() -> Int32 {
        return faissIdQueue.sync {
            let next = _faissID
            _faissID += 1
            return next
        }
    }

    func saveChunk(file: String, chunkIndex: Int, text: String, embedding: [Float], device: String) {
        guard !embedding.isEmpty else {
            print("⚠️ Skipping save: empty embedding")
            return
        }

        let currentFaissID = getNextFaissID()

        do {
            // Convert embedding to blob
            let data = Data(buffer: UnsafeBufferPointer(start: embedding, count: embedding.count))
            let blob = Blob(bytes: [UInt8](data))

            // Save to SQLite
            let insert = chunks.insert(
                self.file <- file,
                self.chunkIndex <- chunkIndex,
                self.text <- text,
                self.embedding <- blob,
                self.device <- device,
                self.faissId <- Int(currentFaissID)
            )
            try db.run(insert)
            print("✅ Saved chunk \(chunkIndex) of '\(file)' to SQLite with faissId: \(currentFaissID)")

            // Add to Faiss
            initializeFaissIfNeeded(dimension: embedding.count)
            try faissIndex?.add([embedding])
            print("✅ Added embedding to Faiss with ID \(currentFaissID)")

        } catch {
            print("❌ Failed to save chunk or embedding: \(error)")
        }
    }

    func retrieve(queryEmbedding: [Float], topK: Int = 3) -> [(chunk: ChunkRecord, score: Float)] {
        guard let faissIndex = self.faissIndex else {
            print("❌ Faiss index is not initialized")
            return []
        }

        do {
            let result = try faissIndex.search([queryEmbedding], k: topK)
            let labels = result.labels.first ?? []
            let distances = result.distances.first ?? []

            var output: [(ChunkRecord, Float)] = []

            for (label, distance) in zip(labels, distances) {
                guard label >= 0 else { continue }

                if let row = try db.pluck(chunks.filter(faissId == Int(label))) {
                    let blob = row[self.embedding]
                    let data = Data(blob.bytes)
                    let floatArray: [Float] = data.withUnsafeBytes {
                        Array($0.bindMemory(to: Float.self))
                    }

                    let chunk = ChunkRecord(
                        id: row[self.id],
                        file: row[self.file],
                        chunkIndex: row[self.chunkIndex],
                        text: row[self.text],
                        embedding: floatArray,
                        device: row[self.device]
                    )
                    output.append((chunk, distance))
                } else {
                    print("⚠️ No SQLite row found for faissId: \(label)")
                }
            }

            return output
        } catch {
            print("❌ Faiss retrieval error: \(error)")
            return []
        }
    }

    // Not supported yet
    func saveFaissIndex(to path: String) {
        print("❌ Saving Faiss index is not supported in SwiftFaiss")
    }

    func loadFaissIndex(from path: String) {
        print("❌ Loading Faiss index from file is not supported in SwiftFaiss")
    }
}
