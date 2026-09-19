import SwiftUI

/// Preview a picture, pick a framing and a piece count, then start.
struct SetupView: View {
    let item: LibraryItem

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.isCompact) private var isCompact

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
        VStack(spacing: 0) {
            header
            Theme.hairline.frame(height: 1)
            GeometryReader { proxy in
                if proxy.size.width >= 860 {
                    HStack(spacing: 0) {
                        preview.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                        ScrollView { panel.padding(26) }
                            .frame(width: 400)
                            .background(Theme.surface)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            preview.padding(.horizontal, 20).padding(.top, 20)
                            panel.padding(20)
                                .background(Theme.surface,
                                            in: RoundedRectangle(cornerRadius: Theme.radiusPanel, style: .continuous))
                                .padding(.horizontal, 16).padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            aspect = settings.defaultAspect
            difficulty = settings.defaultDifficulty
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            RoundIconButton(symbol: "chevron.left") { model.showLibrary() }
                .accessibilityLabel(Text("Back"))
                .keyboardShortcut(.cancelAction)
            Text(item.title)
                .font(Theme.display(22))
                .lineLimit(1)
            Tag(text: item.category.title)
            Spacer()
        }
        .padding(.horizontal, isCompact ? 16 : 26)
        .frame(height: 70)
    }

    private var preview: some View {
        VStack(spacing: 18) {
            // The lattice is layered *inside* the aspect-ratio frame, so it can
            // never spill past the edges of the picture it describes.
            LibraryThumbnail(item: item, longSide: 1200)
                .overlay { LatticeOverlay(columns: grid.columns, rows: grid.rows) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusPanel, style: .continuous))
                .aspectRatio(boardAspect, contentMode: .fit)
                .frame(maxHeight: isCompact ? 300 : 520)
                .shadow(color: .black.opacity(0.24), radius: 16, y: 10)
                .animation(.easeInOut(duration: 0.2), value: boardAspect)

            HStack(spacing: 12) {
                Text("\(grid.columns) × \(grid.rows)")
                    .font(Theme.display(24).monospacedDigit())
                Circle().fill(Theme.track).frame(width: 6, height: 6)
                Text("\(grid.columns * grid.rows) pieces · \(estimate)")
                    .font(Theme.body(17))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// The nearest preset's estimate for a custom count.
    private var estimate: String {
        (Difficulty.allCases.min { abs($0.targetPieces - targetPieces) < abs($1.targetPieces - targetPieces) }
            ?? .normal).estimate
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Kicker(text: "Framing")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(PuzzleAspect.allCases) { option in
                        let selected = option == aspect
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { aspect = option }
                        } label: {
                            Text(option.title)
                                .font(Theme.body(15, selected ? .bold : .semibold))
                                .foregroundStyle(selected ? Theme.onAccent : Theme.text)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(selected ? Theme.accent : Theme.card, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                Text("“Original” keeps the whole picture. The other options crop from the centre — nothing is ever stretched.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Kicker(text: "Difficulty")
                    Spacer()
                    Toggle("Custom", isOn: $useCustomCount.animation(.easeOut(duration: 0.18)))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.muted)
                }

                if useCustomCount {
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: $customCount,
                               in: Double(Difficulty.bounds.lowerBound)...Double(Difficulty.bounds.upperBound),
                               step: 1)
                        Text("\(Int(customCount.rounded())) pieces")
                            .font(Theme.body(15).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        ForEach(Difficulty.allCases) { option in
                            DifficultyRow(difficulty: option, aspect: boardAspect,
                                          isSelected: option == difficulty) {
                                withAnimation(.easeOut(duration: 0.15)) { difficulty = option }
                            }
                        }
                    }
                }

                if targetPieces >= Difficulty.insane.targetPieces {
                    Label("Large puzzles take a moment to cut and are best played with “Scatter Pieces”.",
                          systemImage: "info.circle")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.muted)
                }
            }

            PillButton(title: "Start puzzle", symbol: "play.fill", size: 20, expand: true) {
                model.start(item: item, aspect: aspect, pieces: targetPieces)
            }
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}

private struct DifficultyRow: View {
    let difficulty: Difficulty
    let aspect: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let grid = PuzzleGeometry.grid(targetPieces: difficulty.targetPieces, aspect: aspect)
        Button(action: action) {
            HStack(spacing: 11) {
                Text("\(difficulty.targetPieces)")
                    .font(Theme.body(13, .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? Theme.accent : Theme.onSageTint)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Theme.onAccent : Theme.sageTint, in: Circle())
                Text(difficulty.title)
                    .font(Theme.body(15, .bold))
                Spacer(minLength: 8)
                Text("\(grid.columns) × \(grid.rows) · \(difficulty.estimate)")
                    .font(Theme.body(12).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(isSelected ? 0.85 : 1)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.faint)
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.text)
            .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 14))
            .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
