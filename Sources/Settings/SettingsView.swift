import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = model.settings

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Show picture guide on the board", isOn: $settings.showGhostImage)
                    Toggle("Outline pieces", isOn: $settings.showPieceOutlines)
                }

                Section("Feedback") {
                    Toggle("Sound", isOn: $settings.soundEnabled)
                    Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                }

                Section("Gameplay") {
                    Picker("Snap assist", selection: $settings.snapAssist) {
                        ForEach(SnapAssist.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Default difficulty", selection: $settings.defaultDifficulty) {
                        ForEach(Difficulty.allCases) {
                            Text("\($0.title) · \($0.targetPieces)").tag($0)
                        }
                    }
                    Picker("Default framing", selection: $settings.defaultAspect) {
                        ForEach(PuzzleAspect.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Saved games") {
                    LabeledContent("Saved games", value: "\(model.savedGames.count)")
                    Button("Reset saved games", role: .destructive) { confirmReset = true }
                }

                Section("About") {
                    LabeledContent("Built-in pictures", value: "\(LibraryCatalog.count)")
                    LabeledContent("My photos", value: "\(model.library.userItems.count)")
                    Text("Pictures are generated on your device and stored locally. The game works entirely offline.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all saved games?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) { model.deleteAllSaves() }
                Button("Cancel", role: .cancel) {}
            }
        }
        // A minimum size is a *window* constraint: the macOS Settings scene needs
        // one, but on iOS this sheet is the phone screen and 460pt forces the
        // form wider than it, clipping the Done button off the trailing edge.
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }
}
