import PhotosUI
import SwiftUI

/// The library screen — the app's home.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    @State private var category: ArtCategory?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isImportingFiles = false
    @State private var importError: String?
    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                if !model.resumable.isEmpty {
                    continueSection
                }
                Section {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            PictureCard(item: item) { model.openSetup(for: item) }
                                .contextMenu { contextMenu(for: item) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                } header: {
                    categoryBar
                }
            }
            .padding(.top, 8)
        }
        .background(.background.secondary)
        .navigationTitle("Jigsaw Puzzle")
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $isImportingFiles,
                      allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
        .onChange(of: photoSelection) { _, selection in
            guard !selection.isEmpty else { return }
            Task { await importPhotos(selection) }
        }
        .alert("Import failed", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .overlay(alignment: .bottom) {
            if isImporting {
                Label("Importing…", systemImage: "arrow.down.circle")
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 20)
            }
        }
        .onAppear { model.refreshSaves() }
    }

    private var items: [LibraryItem] {
        model.library.items(in: category)
    }

    // MARK: - Sections

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Continue")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(model.resumable) { snapshot in
                        ResumeCard(snapshot: snapshot) {
                            model.resume(snapshot)
                        } onDelete: {
                            model.delete(snapshot)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: String(localized: "All"), symbol: "square.grid.2x2", value: nil)
                ForEach(ArtCategory.allCases) { candidate in
                    chip(title: candidate.title, symbol: candidate.symbol, value: candidate)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func chip(title: String, symbol: String, value: ArtCategory?) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { category = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(category == value ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: Capsule())
                .foregroundStyle(category == value ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(category == value ? [.isSelected] : [])
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 20, matching: .images) {
                Label("Add Photo", systemImage: "photo.badge.plus")
            }
            Button { isImportingFiles = true } label: {
                Label("Import from Files", systemImage: "folder.badge.plus")
            }
            Button { model.showSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: LibraryItem) -> some View {
        Button { model.openSetup(for: item) } label: { Label("Start Puzzle", systemImage: "play") }
        if item.isUserPhoto {
            Button(role: .destructive) {
                model.library.delete(item)
            } label: {
                Label("Delete Photo", systemImage: "trash")
            }
        }
    }

    // MARK: - Import

    private func importPhotos(_ selection: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            photoSelection = []
        }
        for entry in selection {
            do {
                guard let data = try await entry.loadTransferable(type: Data.self) else { continue }
                if model.library.importPhoto(data: data, suggestedTitle: nil) == nil {
                    importError = model.library.lastError
                        ?? String(localized: "This image format is not supported.")
                }
            } catch {
                importError = error.localizedDescription
            }
        }
        category = .mine
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            for url in urls where model.library.importPhoto(url: url) == nil {
                importError = model.library.lastError
                    ?? String(localized: "This image format is not supported.")
            }
            category = .mine
        case let .failure(error):
            importError = error.localizedDescription
        }
    }
}

// MARK: - Cards

private struct PictureCard: View {
    let item: LibraryItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                LibraryThumbnail(item: item)
                    .aspectRatio(3.0 / 2.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(item.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityHint(Text("Opens puzzle options"))
    }
}

private struct ResumeCard: View {
    let snapshot: GameSnapshot
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LibraryThumbnail(item: snapshot.libraryItem, longSide: 220)
                    .frame(width: 84, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.itemTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text("\(snapshot.pieceCount) pieces · \(TimeFormatting.clock(snapshot.elapsed))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(snapshot.state.placedCount),
                                 total: Double(max(1, snapshot.pieceCount)))
                        .frame(width: 150)
                }
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Saved Game", systemImage: "trash")
            }
        }
    }
}
