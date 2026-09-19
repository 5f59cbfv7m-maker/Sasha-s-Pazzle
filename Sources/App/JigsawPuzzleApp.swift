import SwiftUI

@main
struct JigsawPuzzleApp: App {
    @State private var model = AppModel()

    init() { Fonts.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                // A minimum size is a *window* constraint. Applying it on iOS
                // forces the layout wider than a phone screen, pushing the HUD
                // and the toolbar off both edges.
                #if os(macOS)
                .frame(minWidth: 620, minHeight: 460)
                #endif
        }
        .commands { GameCommands(model: model) }
        #if os(macOS)
        .defaultSize(width: 1320, height: 880)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(model)
                .environment(model.settings)
        }
        #endif
    }
}
