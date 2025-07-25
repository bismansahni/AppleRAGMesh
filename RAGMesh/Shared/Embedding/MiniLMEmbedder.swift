//
//  MiniLMEmbedder.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import CoreML
import Foundation
import Tokenizers
import Models
import Path

public struct MiniLMEmbedder {
    public static func embedReturningChunks(text inputText: String, filePath: String) async -> [EmbeddedChunk] {
        var results: [EmbeddedChunk] = []

        do {
            guard let vocabPath = Bundle.main.path(forResource: "vocab", ofType: "txt") else { return [] }

            
            let vocabContent = try String(contentsOf: URL(fileURLWithPath: vocabPath.string), encoding: .utf8)
            let vocab = vocabContent
                .split(separator: "\n")
                .enumerated()
                .reduce(into: [String: Int]()) { $0[String($1.element)] = $1.offset }


            let tokenizer = BertTokenizer(vocab: vocab, merges: nil)
            let tokenList = tokenizer.tokenize(text: inputText).filter { $0 != "[UNK]" }
            let chunks = tokenList.chunked(into: 128)

            guard let modelUrl = Bundle.main.url(forResource: "minilm", withExtension: "mlmodelc") else { return [] }
            let model = try MLModel(contentsOf: modelUrl)

            for (index, chunk) in chunks.enumerated() {
                let inputIds = chunk.map { vocab[$0] ?? vocab["[UNK]"]! }
                let attentionMask = Array(repeating: 1, count: inputIds.count)

                let inputArray = try MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32)
                let attentionArray = try MLMultiArray(shape: [1, NSNumber(value: attentionMask.count)], dataType: .int32)

                for (i, id) in inputIds.enumerated() {
                    inputArray[[0, i] as [NSNumber]] = NSNumber(value: id)
                    attentionArray[[0, i] as [NSNumber]] = NSNumber(value: 1)
                }

                let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
                    "input_ids": inputArray,
                    "attention_mask": attentionArray
                ])

                let prediction = try await model.prediction(from: inputFeatures)
                if let embedding = prediction.featureValue(for: "pooler_output")?.multiArrayValue {
                    let floatArray = (0..<embedding.count).map { Float(truncating: embedding[$0]) }
                    let decoded = decodeWordPieceTokens(chunk)
                    results.append(.init(chunkIndex: index, text: decoded, embedding: floatArray))
                }
            }
        } catch {
            print("❌ Embedding error: \(error)")
        }

        return results
    }

    private static func decodeWordPieceTokens(_ tokens: [String]) -> String {
        var output = [String]()
        var current = ""

        for token in tokens {
            if token.hasPrefix("##") {
                current += String(token.dropFirst(2))
            } else {
                if !current.isEmpty { output.append(current) }
                current = token
            }
        }
        if !current.isEmpty { output.append(current) }

        return output.joined(separator: " ")
    }
}
