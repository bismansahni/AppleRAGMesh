



import Foundation
import CoreML
import Models
import Generation

class ModelLoader {
    private static var cachedModel: LanguageModel?

    static func preload() async {
        guard cachedModel == nil else {
            print("♻️ [ModelLoader] Model already cached")
            return
        }

        print("📦 [ModelLoader] Preloading model from bundle...")
        guard let modelURL = Bundle.main.url(forResource: "StatefulMistral7BInstructInt4", withExtension: "mlmodelc") else {
            print("❌ [ModelLoader] .mlmodelc not found")
            return
        }

        do {
            let model = try LanguageModel.loadCompiled(url: modelURL, computeUnits: .cpuAndGPU)
            cachedModel = model
            print("✅ [ModelLoader] Model preloaded and cached")
        } catch {
            print("❌ [ModelLoader] Preload failed: \(error.localizedDescription)")
        }
    }

    static func load() throws -> LanguageModel {
        guard let model = cachedModel else {
            throw NSError(domain: "Model not preloaded", code: 2, userInfo: [NSLocalizedDescriptionKey: "Model not yet loaded"])
        }
        return model
    }
}

func runGeneration(with context: String, question: String, sourceSummary: String, onAnswer: ((String) -> Void)? = nil) async {

    
   
    let prompt = """
    Answer the following question using only the context below.
    Do not rely on prior knowledge.
    If the context does not contain the answer, respond with:
    No relevant details found from your filesystem.

    Instructions:
    - Keep the answer brief and specific.
    - Use clear and professional language.
    - Avoid unnecessary repetition or filler.

    ---

    Context:
    \(context)

    Question:
    \(question)

    Answer:
    """



    print("📝 Prompt:\n\(prompt)")
    print("🔢 Token estimate: \(prompt.split { $0.isWhitespace || $0.isNewline }.count)")

    let config = GenerationConfig(
        maxNewTokens: 400,
        temperature: 0.7,
        topK: 50,
        topP: 0.95
    )

    do {
        print("🚀 Fetching cached model...")
        let model = try ModelLoader.load()

        print("🚀 Starting generation...")
        let rawOutput = try await model.generate(config: config, prompt: prompt)

        let output: String
        if let range = rawOutput.range(of: "Answer:") {
            output = rawOutput[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            output = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        print("✅ Output generated:\n\(output)")

        await MainActor.run {
            onAnswer?("\(output)\n\n📁 Sources: \(sourceSummary)")
        }
    } catch {
        print("❌ Generation failed: \(error)")
        await MainActor.run {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}
