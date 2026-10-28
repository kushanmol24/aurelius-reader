
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

@main
struct AureliusApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
    }
}

struct LibraryView: View {
    @State private var files: [URL] = []
    @State private var showImporter = false
    @State private var selectedPDF: URL?
    @State private var errorMessage: String?

    private var libraryURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Library", isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    ContentUnavailableView {
                        Label("Your Library", systemImage: "books.vertical")
                    } description: {
                        Text("Import a PDF to begin reading.")
                    } actions: {
                        Button("Import Books") {
                            showImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(files, id: \.absoluteString) { url in
                            Button {
                                if url.pathExtension.lowercased() == "pdf" {
                                    selectedPDF = url
                                } else {
                                    errorMessage =
                                        "EPUB reading will be added in a later build."
                                }
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .foregroundStyle(.primary)
                                        Text(url.pathExtension.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName:
                                        url.pathExtension.lowercased() == "pdf"
                                        ? "doc.richtext"
                                        : "book")
                                }
                            }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("Aurelius")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf, .epub],
                allowsMultipleSelection: true,
                onCompletion: importFiles
            )
            .sheet(item: Binding(
                get: { selectedPDF.map(PDFSelection.init) },
                set: { selectedPDF = $0?.url }
            )) { selection in
                PDFReaderView(url: selection.url)
            }
            .alert(
                "Aurelius",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: loadLibrary)
        }
        .tint(Color(red: 0.20, green: 0.36, blue: 0.27))
    }

    private func loadLibrary() {
        do {
            try FileManager.default.createDirectory(
                at: libraryURL,
                withIntermediateDirectories: true
            )
            files = try FileManager.default.contentsOfDirectory(
                at: libraryURL,
                includingPropertiesForKeys: nil
            )
            .filter { ["pdf", "epub"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare(
                $1.lastPathComponent
            ) == .orderedAscending }
        } catch {
            errorMessage = "Unable to load your library: \(error.localizedDescription)"
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for source in urls {
                let ext = source.pathExtension.lowercased()
                guard ["pdf", "epub"].contains(ext) else { continue }

                let access = source.startAccessingSecurityScopedResource()
                defer {
                    if access {
                        source.stopAccessingSecurityScopedResource()
                    }
                }

                let destination = libraryURL.appendingPathComponent(
                    source.lastPathComponent
                )

                if FileManager.default.fileExists(atPath: destination.path) {
                    continue
                }

                try FileManager.default.copyItem(
                    at: source,
                    to: destination
                )
            }
            loadLibrary()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            do {
                try FileManager.default.removeItem(at: files[index])
            } catch {
                errorMessage = "Unable to remove the imported copy."
            }
        }
        loadLibrary()
    }
}

private struct PDFSelection: Identifiable {
    let url: URL
    var id: String { url.absoluteString }

    init(_ url: URL) {
        self.url = url
    }
}

struct PDFReaderView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .navigationTitle(url.deletingPathExtension().lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
