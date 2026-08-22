import SwiftUI

@main
struct JigsawPuzzleApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .frame(minWidth: 640, minHeight: 460)
        }
        .commands { GameCommands(model: model) }
        #if os(macOS)
        .defaultSize(width: 1320, height: 880)
        .windowToolbarStyle(.unified)
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
