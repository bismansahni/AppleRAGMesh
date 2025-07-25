




import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    private var peerClient = PeerClient()
    @State private var showFileImporter = false
    @State private var embeddedChunks: [String] = []
    @State private var showingSuccessToast = false
    @State private var selectedFileNames: [String] = []

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
            }

            if showingSuccessToast {
                successToast
            }
        }
        .background(Color(.systemBackground))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .text, .utf8PlainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let fileNames = urls.map { $0.lastPathComponent }
                selectedFileNames = fileNames

                for url in urls {
                    handleSelectedFile(url)
                }

                withAnimation {
                    showingSuccessToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showingSuccessToast = false
                    }
                }

            case .failure(let error):
                print("❌ File selection failed: \(error)")
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Document Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Button(action: {
                showFileImporter = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Documents")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }

            if !selectedFileNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedFileNames, id: \.self) { fileName in
                            HStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.caption)
                                Text(fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
    }

    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                VStack(alignment: .leading) {
                    Text("Files Selected Successfully")
                        .font(.headline)

                    if selectedFileNames.count == 1 {
                        Text(selectedFileNames[0])
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(selectedFileNames.count) files selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private func handleSelectedFile(_ url: URL) {
        Task {
            do {
                print("📥 Selected file: \(url.lastPathComponent)")
                let content = try await readFileText(from: url)
                print("🧾 Extracted content length: \(content.count)")

                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ Empty content from \(url.lastPathComponent)")
                    return
                }

                await peerClient.sendEmbeddingRequestToMac(text: content, fileName: url.lastPathComponent)

                await MainActor.run {
                    embeddedChunks.append(content)
                }

            } catch {
                print("❌ Failed to import \(url.lastPathComponent): \(error)")
            }
        }
    }

    private func readFileText(from url: URL) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "AccessDenied", code: 1, userInfo: [NSLocalizedDescriptionKey: "No permission to access file"])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if url.pathExtension.lowercased() == "pdf" {
            return extractTextFromPDF(at: url)
        } else {
            return try String(contentsOf: url)
        }
    }

    private func extractTextFromPDF(at url: URL) -> String {
        guard let doc = PDFDocument(url: url) else {
            print("❌ PDFDocument could not open \(url.lastPathComponent)")
            return ""
        }

        var text = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
