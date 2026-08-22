import SwiftUI

/// Preview a picture, pick a framing and a piece count, then start.
struct SetupView: View {
    let item: LibraryItem

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    @State private var aspect: PuzzleAspect = .original
    @State private var difficulty: Difficulty = .normal
    @State private var useCustomCount = false
    @State private var customCount: Double = 200

    private var targetPieces: Int {
        useCustomCount ? Int(customCount.rounded()) : difficulty.targetPieces
    }

    private var boardAspect: CGFloat { aspect.ratio ?? item.aspect }

    private var grid: (columns: Int, rows: Int) {
        PuzzleGeometry.grid(targetPieces: targetPieces, aspect: boardAspect)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                preview
                framing
                difficultySection
                startButton
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(.background.secondary)
        .navigationTitle(item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            aspect = settings.defaultAspect
            difficulty = settings.defaultDifficulty
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            // The lattice is layered *inside* the aspect-ratio frame, so it can
            // never spill past the edges of the picture it describes.
            LibraryThumbnail(item: item, longSide: 1200)
                .overlay { GridPreview(columns: grid.columns, rows: grid.rows) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .aspectRatio(boardAspect, contentMode: .fit)
                .frame(maxHeight: 340)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                .animation(.easeInOut(duration: 0.2), value: boardAspect)

            Text("\(grid.columns) × \(grid.rows) = \(grid.columns * grid.rows) pieces")
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var framing: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Framing").font(.headline)
            Picker("Framing", selection: $aspect) {
                ForEach(PuzzleAspect.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("“Original” keeps the whole picture. The other options crop from the centre — nothing is ever stretched.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Difficulty").font(.headline)
                Spacer()
                Toggle("Custom", isOn: $useCustomCount.animation(.easeOut(duration: 0.18)))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if useCustomCount {
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $customCount,
                           in: Double(Difficulty.bounds.lowerBound)...Double(Difficulty.bounds.upperBound),
                           step: 1)
                    Text("\(Int(customCount.rounded())) pieces")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 176, maximum: 240), spacing: 12)],
                          spacing: 12) {
                    ForEach(Difficulty.allCases) { option in
                        DifficultyCard(difficulty: option, isSelected: option == difficulty) {
                            withAnimation(.easeOut(duration: 0.15)) { difficulty = option }
                        }
                    }
                }
            }

            if targetPieces >= 300 {
                Label("Large puzzles take a moment to cut and are best played with “Scatter Pieces”.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var startButton: some View {
        Button {
            model.start(item: item, aspect: aspect, pieces: targetPieces)
        } label: {
            Label("Start", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: [])
    }
}

/// Faint lattice showing how the picture will be divided.
private struct GridPreview: View {
    let columns: Int
    let rows: Int

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for column in 1..<max(1, columns) {
                let x = size.width * CGFloat(column) / CGFloat(columns)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 1..<max(1, rows) {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DifficultyCard: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: difficulty.symbol)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                VStack(alignment: .leading, spacing: 1) {
                    Text(difficulty.title).font(.subheadline.weight(.semibold))
                    Text("\(difficulty.targetPieces) · \(difficulty.estimate)")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85))
                                                    : AnyShapeStyle(.secondary))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.background),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(isSelected ? 0 : 0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
