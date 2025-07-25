


import CoreML
import Path
import Models
import Tokenizers
import Foundation

struct EmbeddedChunk {
    let chunkIndex: Int
    let text: String
    let embedding: [Float]
}

struct MiniLMEmbedder {}

extension MiniLMEmbedder {
    static func embedReturningChunks(text inputText: String, filePath: String) async -> [EmbeddedChunk] {
        print("🧠 Embedding text from \(filePath)")
        var results: [EmbeddedChunk] = []

        do {
            guard let vocabPath = Bundle.main.path(forResource: "vocab", ofType: "txt") else {
                print("❌ vocab.txt missing")
                return []
            }

            let vocabContent = try String(contentsOf: URL(fileURLWithPath: vocabPath.string), encoding: .utf8)
            let tokens = vocabContent.split(separator: "\n").map(String.init)
            var vocab: [String: Int] = [:]
            for (i, token) in tokens.enumerated() {
                vocab[token] = i
            }

            let tokenizer = BertTokenizer(vocab: vocab, merges: nil)
            let tokenList = tokenizer.tokenize(text: inputText).filter { $0 != "[UNK]" }
            let chunkSize = 128
            let chunks = tokenList.chunked(into: chunkSize)

            guard let modelUrl = Bundle.main.url(forResource: "minilm", withExtension: "mlmodelc") else {
                print("❌ Model file not found")
                return []
            }

            let model = try MLModel(contentsOf: modelUrl)

            for (index, chunk) in chunks.enumerated() {
                let inputIds = chunk.map { vocab[$0] ?? vocab["[UNK]"]! }
                let attentionMask = Array(repeating: 1, count: inputIds.count)

                let inputArray = try MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32)
                let attentionArray = try MLMultiArray(shape: [1, NSNumber(value: attentionMask.count)], dataType: .int32)

                for (i, id) in inputIds.enumerated() {
                    inputArray[[0, i] as [NSNumber]] = NSNumber(value: id)
                }
                for (i, mask) in attentionMask.enumerated() {
                    attentionArray[[0, i] as [NSNumber]] = NSNumber(value: mask)
                }

                let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
                    "input_ids": inputArray,
                    "attention_mask": attentionArray
                ])

                let prediction = try await model.prediction(from: inputFeatures)

                if let embedding = prediction.featureValue(for: "pooler_output")?.multiArrayValue {
                    let floatArray = (0..<embedding.count).map { Float(truncating: embedding[$0]) }
                    let decodedText = decodeWordPieceTokens(chunk)

                    results.append(.init(chunkIndex: index, text: decodedText, embedding: floatArray))
                }
            }

        } catch {
            print("❌ Embedding error: \(error)")
        }

        return results
    }

    private static func decodeWordPieceTokens(_ tokens: [String]) -> String {
        var tokenList: [String] = []
        var currentToken = ""

        for token in tokens {
            if token.starts(with: "##") {
                currentToken += String(token.dropFirst(2))
            } else {
                if !currentToken.isEmpty {
                    tokenList.append(currentToken)
                }
                currentToken = token
            }
        }

        if !currentToken.isEmpty {
            tokenList.append(currentToken)
        }

        return tokenList.joined(separator: " ")
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
