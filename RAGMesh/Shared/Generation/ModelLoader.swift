//
//  ModelLoader.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import CoreML
import Models
import Generation
import Foundation

public class ModelLoader {
    private static var cachedModel: LanguageModel?

    public static func preload() async {
        guard cachedModel == nil else { return }
        guard let modelURL = Bundle.main.url(forResource: "StatefulMistral7BInstructInt4", withExtension: "mlmodelc") else { return }
        do {
            cachedModel = try LanguageModel.loadCompiled(url: modelURL, computeUnits: .cpuAndGPU)
        } catch {
            print("❌ Failed to preload generation model: \(error)")
        }
    }

    public static func load() throws -> LanguageModel {
        guard let model = cachedModel else {
            throw NSError(domain: "ModelNotLoaded", code: 1, userInfo: nil)
        }
        return model
    }
}

public func runGeneration(with context: String, question: String, sourceSummary: String, onAnswer: ((String) -> Void)? = nil) async {
    let prompt = """
    Answer the following question using only the context below.
    Do not rely on prior knowledge.
    If the context does not contain the answer, respond with:
    No relevant details found from your filesystem.

    ---

    Context:
    \(context)

    Question:
    \(question)

    Answer:
    """

    do {
        let model = try ModelLoader.load()
        let config = GenerationConfig(maxNewTokens: 400, temperature: 0.7, topK: 50, topP: 0.95)
        let raw = try await model.generate(config: config, prompt: prompt)

        let output = raw.components(separatedBy: "Answer:").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
        await MainActor.run {
            onAnswer?("\(output)\n\n📁 Sources: \(sourceSummary)")
        }
    } catch {
        print("❌ Generation failed: \(error)")
    }
}
