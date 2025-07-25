
import CoreML
import Path
import Models
import Tokenizers

struct MiniLMEmbedderForQuestion {
    static func embed(question: String) async -> [Float]? {
        LogManager.shared.append("🤖 Embedding question: \(question)")

        do {
       
            
            guard let vocabPath = Bundle.main.path(forResource: "vocab", ofType: "txt") else {
                print("❌ Failed to find vocab.txt in bundle")
                LogManager.shared.append("❌ Failed to find vocab.txt in bundle.")
                return nil
            }
            
            let vocabContent = try String(contentsOf: URL(fileURLWithPath: vocabPath.string), encoding: .utf8)

            
            
            let tokens = vocabContent.split(separator: "\n").map(String.init)
            var vocab: [String: Int] = [:]
            for (i, token) in tokens.enumerated() {
                vocab[token] = i
            }

            let tokenizer = BertTokenizer(vocab: vocab, merges: nil)
            
            

            
            let maxTokens = 128
            let tokenList = tokenizer.tokenize(text: question)

            let trimmedTokens = Array(tokenList.prefix(maxTokens))
            let inputIds = trimmedTokens.map { vocab[$0] ?? vocab["[UNK]"]! }
            let attentionMask = Array(repeating: 1, count: inputIds.count)


            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32)
            let attentionArray = try MLMultiArray(shape: [1, NSNumber(value: attentionMask.count)], dataType: .int32)
            for (i, id) in inputIds.enumerated() {
                inputArray[[0, i] as [NSNumber]] = NSNumber(value: id)
            }
            for (i, mask) in attentionMask.enumerated() {
                attentionArray[[0, i] as [NSNumber]] = NSNumber(value: mask)
            }

            
            
            guard let modelUrl = Bundle.main.url(forResource: "minilm", withExtension: "mlmodelc") else {
                print("❌ Failed to find Minilm.mlpackage in bundle.")
                LogManager.shared.append("❌ Failed to find Minilm.mlpackage in bundle.")
                return nil
            }
            


            let model = try MLModel(contentsOf: modelUrl)
            
            
            
            
            

            let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputArray,
                "attention_mask": attentionArray
            ])
            let prediction = try await model.prediction(from: inputFeatures)

            if let embeddingArray = prediction.featureValue(for: "pooler_output")?.multiArrayValue {
                let floatArray = (0..<embeddingArray.count).map { Float(truncating: embeddingArray[$0]) }
                LogManager.shared.append("📏 Question embedding size: \(floatArray.count)")
                return floatArray
            }

        } catch {
            LogManager.shared.append("❌ Failed to embed question: \(error)")
        }

        return nil
    }
}


