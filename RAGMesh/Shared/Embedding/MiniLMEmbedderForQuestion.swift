//
//  MiniLMEmbedderForQuestion.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import CoreML
import Tokenizers
import Models
import Foundation
import Path

public struct MiniLMEmbedderForQuestion {
    public static func embed(question: String) async -> [Float]? {
        do {
            guard let vocabPath = Bundle.main.path(forResource: "vocab", ofType: "txt") else { return nil }

            
            let vocabContent = try String(contentsOf: URL(fileURLWithPath: vocabPath.string), encoding: .utf8)
            let vocab = vocabContent.split(separator: "\n").enumerated().reduce(into: [String: Int]()) {
                $0[String($1.element)] = $1.offset
            }


            let tokenizer = BertTokenizer(vocab: vocab, merges: nil)
            let tokenList = Array(tokenizer.tokenize(text: question).prefix(128))
            let inputIds = tokenList.map { vocab[$0] ?? vocab["[UNK]"]! }

            let attentionMask = Array(repeating: 1, count: inputIds.count)
            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32)
            let attentionArray = try MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32)

            for (i, id) in inputIds.enumerated() {
                inputArray[[0, i] as [NSNumber]] = NSNumber(value: id)
                attentionArray[[0, i] as [NSNumber]] = NSNumber(value: 1)
            }

            guard let modelUrl = Bundle.main.url(forResource: "minilm", withExtension: "mlmodelc") else { return nil }
            let model = try MLModel(contentsOf: modelUrl)

            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputArray,
                "attention_mask": attentionArray
            ])
            let result = try await model.prediction(from: input)

            if let output = result.featureValue(for: "pooler_output")?.multiArrayValue {
                return (0..<output.count).map { Float(truncating: output[$0]) }
            }
        } catch {
            print("❌ Question embedding error: \(error)")
        }
        return nil
    }
}
