import SwiftUI

/// Shown while the picture is decoded and the pieces are cut.
struct LoadingOverlay: View {
    let session: GameSession

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 16) {
                ProgressView(value: max(0.02, session.textures.progress))
                    .progressViewStyle(.linear)
                    .frame(width: 220)
                Text("Cutting \(session.pieceCount) pieces…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
        .accessibilityElement()
        .accessibilityLabel(Text("Preparing puzzle"))
    }
}

struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Something went wrong").font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Back to Library", action: onDismiss)
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct PauseOverlay: View {
    let session: GameSession

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 18) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                Text("Paused").font(.title2.weight(.semibold))
                Text(TimeFormatting.clock(session.elapsed))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    session.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill").frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
            }
            .padding(34)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .transition(.opacity)
    }
}

struct CompletionOverlay: View {
    let session: GameSession
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .rotationEffect(.degrees(appeared ? 0 : -25))

                Text("Puzzle solved!")
                    .font(.largeTitle.weight(.bold))

                VStack(spacing: 6) {
                    statRow("Time", TimeFormatting.clock(session.elapsed))
                    statRow("Pieces", "\(session.pieceCount)")
                    statRow("Picture", session.item.title)
                }
                .font(.callout)
                .frame(maxWidth: 320)

                HStack(spacing: 12) {
                    Button {
                        model.restartCurrent()
                    } label: {
                        Label("New Puzzle", systemImage: "arrow.clockwise").frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.showLibrary()
                    } label: {
                        Label("Choose Photo", systemImage: "photo.on.rectangle").frame(minWidth: 120)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(38)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 30, y: 12)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appeared = true }
        }
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

/// Full-size reference view of the picture being assembled.
struct OriginalImageSheet: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let ghost = session.ghostImage {
                    ghost
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(session.item.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Same window-constraint trap: on a phone this sheet is already the full
        // screen, and 520pt pushes the navigation bar past both edges.
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 380)
        #endif
    }
}
