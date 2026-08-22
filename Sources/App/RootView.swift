import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: AppModel.Route.self) { route in
                    switch route {
                    case let .setup(itemID):
                        if let item = model.library.item(id: itemID) {
                            SetupView(item: item)
                        } else {
                            ContentUnavailableView("Picture not found", systemImage: "photo")
                        }
                    case .game:
                        if let session = model.session {
                            GameView(session: session)
                        } else {
                            ContentUnavailableView("No game in progress", systemImage: "puzzlepiece")
                        }
                    }
                }
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
        }
        .preferredColorScheme(model.settings.appearance.colorScheme)
        .environment(model.settings)
        #if DEBUG
        .task { await DebugStageDriver.run(model: model) }
        #endif
    }
}
