import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = model.settings

        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(Theme.display(28))
                Spacer()
                PillButton(title: "Done", size: 15) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(EdgeInsets(top: 26, leading: 26, bottom: 18, trailing: 26))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("Appearance") {
                        row("Theme") {
                            PillSegments(options: AppSettings.Appearance.allCases,
                                         selection: $settings.appearance) { $0.title }
                        }
                        toggle("Picture guide on the table", $settings.showGhostImage)
                        toggle("Outline pieces", $settings.showPieceOutlines)
                    }
                    group("Feedback") {
                        toggle("Sounds", $settings.soundEnabled)
                        if Feedback.hasMusic {
                            toggle("Background music", $settings.musicEnabled)
                        }
                        #if os(iOS)
                        toggle("Haptic feedback", $settings.hapticsEnabled)
                        #endif
                    }
                    group("Gameplay") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Snap assist").font(Theme.body(16))
                                Spacer()
                                Text(settings.snapAssist.title)
                                    .font(Theme.body(14, .bold)).foregroundStyle(Theme.accentDeep)
                            }
                            PillSegments(options: SnapAssist.allCases,
                                         selection: $settings.snapAssist, title: { $0.title }, expand: true)
                        }
                        .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
                        row("Default difficulty") {
                            Picker("Default difficulty", selection: $settings.defaultDifficulty) {
                                ForEach(Difficulty.allCases) {
                                    Text("\($0.title) · \($0.targetPieces)").tag($0)
                                }
                            }
                            .labelsHidden()
                        }
                        row("Default framing") {
                            Picker("Default framing", selection: $settings.defaultAspect) {
                                ForEach(PuzzleAspect.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                        }
                    }
                    group("Saved games") {
                        row("Saved games") {
                            Text("\(model.savedGames.count)")
                                .font(Theme.body(14, .bold)).foregroundStyle(Theme.muted)
                                .padding(.horizontal, 11).padding(.vertical, 3)
                                .background(Theme.surface, in: Capsule())
                        }
                        row("Puzzles solved") {
                            Text("\(model.stats.puzzlesSolved)")
                                .font(Theme.body(14, .bold)).foregroundStyle(Theme.muted)
                                .padding(.horizontal, 11).padding(.vertical, 3)
                                .background(Theme.surface, in: Capsule())
                        }
                        Button { confirmReset = true } label: {
                            Text("Reset saved games and statistics")
                                .font(Theme.body(16, .bold))
                                .foregroundStyle(Theme.accentDeep)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Sasha's Puzzles · \(LibraryCatalog.count) built-in pictures · \(model.library.userItems.count) of your photos · works entirely offline")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.faint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(EdgeInsets(top: 0, leading: 22, bottom: 26, trailing: 22))
            }
        }
        .background(Theme.surface)
        .tint(Theme.accent)
        .foregroundStyle(Theme.text)
        .confirmationDialog("Delete all saved games and statistics?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteAllSaves()
                model.stats.reset()
            }
            Button("Cancel", role: .cancel) {}
        }
        // A minimum size is a *window* constraint: the macOS Settings scene needs
        // one, but on iOS this sheet is the phone screen and 460pt forces the
        // form wider than it, clipping the Done button off the trailing edge.
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    // MARK: - Building blocks

    private func group<Content: View>(_ title: LocalizedStringKey,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: title).padding(.horizontal, 12)
            Group(subviews: content()) { rows in
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        row
                        if row.id != rows.last?.id {
                            Theme.hairline.frame(height: 1).padding(.horizontal, 14)
                        }
                    }
                }
            }
            .padding(6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func row<Trailing: View>(_ title: LocalizedStringKey,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Text(title).font(Theme.body(16))
            Spacer()
            trailing()
        }
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
    }

    private func toggle(_ title: LocalizedStringKey, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { Text(title).font(Theme.body(16)) }
            .toggleStyle(.switch)
            .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
    }
}
