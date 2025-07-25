//
//  MacMainView.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import SwiftUI


struct MacMainView: View {
    @State private var question: String = ""
    @State private var answer: String? = nil
    @StateObject private var broadcaster = Broadcaster()
    @FocusState private var isFocused: Bool
    @State private var glowPhase: CGFloat = 0.0
    @State private var contentHeight: CGFloat = 120
    @State private var isWaiting = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                ZStack {
                    HStack(spacing: 0) {
                        TextField("Ask about your files...", text: $question, onCommit: sendQuery)
                            .font(.system(size: 16))
                            .fontWeight(.medium)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .focused($isFocused)
                    }
                    .frame(height: 90)
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(
                                        isWaiting ?
                                        AnyShapeStyle(AngularGradient(
                                            gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .yellow, .blue]),
                                            center: .center,
                                            angle: .degrees(glowPhase)
                                        )) :
                                        AnyShapeStyle(Color.clear),
                                        lineWidth: 3
                                    )
                            )
                    )
                    .cornerRadius(30)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                if isWaiting {
                    responseBubble(text: "Working with your nearby iPhone and iPad…", italic: true)
                } else if let answer = answer, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    responseBubble(text: answer)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            contentHeight = proxy.size.height
                            NotificationCenter.default.post(name: .didUpdateContentHeight, object: contentHeight)
                        }
                        .onChange(of: proxy.size.height) { newHeight in
                            contentHeight = newHeight
                            NotificationCenter.default.post(name: .didUpdateContentHeight, object: newHeight)
                        }
                }
            )
        }
        .frame(height: contentHeight)
        .background(Color.clear)
        .onAppear {
            startGlowLoop()
            NotificationCenter.default.addObserver(forName: .didReceiveFinalAnswer, object: nil, queue: .main) { notif in
                if let newAnswer = notif.object as? String {
                    withAnimation(.easeOut(duration: 0.35)) {
                        self.answer = newAnswer
                        self.isWaiting = false
                    }
                }
            }
        }
    }

    private func sendQuery() {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        answer = nil
        isWaiting = true
        isFocused = false
        broadcaster.currentQuestion = question

        Task {
            if let embedding = await MiniLMEmbedderForQuestion.embed(question: question) {
                broadcaster.broadcastEmbeddingQuery(vector: embedding)
            }
        }
    }

    private func startGlowLoop() {
        Task {
            while true {
                if isWaiting {
                    await MainActor.run {
                        glowPhase += 10
                    }
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func responseBubble(text: String, italic: Bool = false) -> some View {
        ZStack {
            HStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .foregroundColor(.white.opacity(italic ? 0.75 : 1))
                    .italic(italic)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            )
            .cornerRadius(30)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeOut(duration: 0.35), value: text)
    }
}
