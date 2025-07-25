import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    private var peerClient = PeerClient()
    @State private var showFileImporter = false
    @State private var selectedFileNames: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            header
            fileSelector
            selectedFilesView
        }
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
                    handleFile(url)
                }

            case .failure(let error):
                print("❌ File import failed: \(error)")
            }
        }
    }

    var header: some View {
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
    }

    var fileSelector: some View {
        Button("Add Documents") {
            showFileImporter = true
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(20)
    }

    var selectedFilesView: some View {
        Group {
            if selectedFileNames.isEmpty {
                AnyView(EmptyView())
            } else {
                AnyView(
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedFileNames, id: \.self) { name in
                                Text(name)
                                    .padding(10)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }.padding()
                    }
                )
            }
        }
    }

    func handleFile(_ url: URL) {
        Task {
            do {
                let content = try await readText(from: url)
                await peerClient.sendEmbeddingRequestToMac(text: content, fileName: url.lastPathComponent)
            } catch {
                print("❌ Reading file failed: \(error)")
            }
        }
    }

    func readText(from url: URL) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "AccessDenied", code: 1, userInfo: nil)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if url.pathExtension.lowercased() == "pdf" {
            return extractPDF(url)
        } else {
            return try String(contentsOf: url)
        }
    }

    func extractPDF(_ url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var text = ""
        for i in 0..<doc.pageCount {
            text += doc.page(at: i)?.string ?? ""
        }
        return text
    }
}
