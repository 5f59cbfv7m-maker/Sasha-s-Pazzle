import SwiftUI

/// Three steps on first launch; each shows the mechanic rather than describing it.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var step = 0
    @State private var pulse = false

    private static let steps: [(title: LocalizedStringKey, text: LocalizedStringKey)] = [
        ("Real locks",
         "Every cut is made once and shared by its two neighbours — pieces meet exactly, with no gaps and no “close enough”."),
        ("Just the help you need",
         "A piece pulls itself into place. The hint highlights the next step — it can be switched off in Settings."),
        ("Your photos are puzzles too",
         "\(LibraryCatalog.count) pictures in the library plus any photo from your gallery: from 12 pieces to 800, framed the way you like."),
    ]

    var body: some View {
        ZStack {
            Theme.bg
            Blob(size: 240).offset(x: 160, y: -260)
            Blob(color: Theme.blob2, size: 230).offset(x: -170, y: 60)
            VStack(spacing: 0) {
                illustration
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(30)
                VStack(alignment: .leading, spacing: 10) {
                    Tag(text: String(localized: "Step \(step + 1) of \(Self.steps.count)"))
                    // The illustration above takes all spare height; without
                    // this a two-line title ("Ваши снимки — тоже пазлы") is cut to one.
                    Text(Self.steps[step].title).font(Theme.display(30)).padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Self.steps[step].text)
                        .font(Theme.body(16)).foregroundStyle(Theme.muted).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        ForEach(0..<Self.steps.count, id: \.self) { index in
                            Capsule().fill(index == step ? Theme.accent : Theme.track)
                                .frame(width: index == step ? 28 : 8, height: 8)
                        }
                        Spacer()
                        PillButton(title: step == Self.steps.count - 1 ? "To the table" : "Next", size: 16) {
                            if step < Self.steps.count - 1 {
                                withAnimation(.easeOut(duration: 0.3)) { step += 1 }
                            } else {
                                onFinish()
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: 460, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: 34, bottom: 34, trailing: 34))
            }
        }
        .ignoresSafeArea()
        .onAppear { pulse = true }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 700)
        #endif
    }

    @ViewBuilder
    private var illustration: some View {
        ZStack {
            Circle().fill(Theme.surface).frame(width: 250, height: 250)
            switch step {
            case 0:
                PuzzleMark(size: 170)
                    .offset(y: pulse ? -5 : 0)
                    .animation(.easeInOut(duration: 2).repeatForever(), value: pulse)
            case 1:
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .frame(width: 210, height: 156)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 4)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.16)))
                    .frame(width: 90, height: 90)
                    .scaleEffect(pulse ? 1.04 : 0.94)
                    .opacity(pulse ? 1 : 0.4)
                    .animation(.easeInOut(duration: 1.2).repeatForever(), value: pulse)
                PuzzleMark(size: 120)
                    .offset(x: pulse ? 92 : 86, y: pulse ? 70 : 80)
                    .rotationEffect(.degrees(pulse ? 3 : 0))
                    .animation(.easeInOut(duration: 3).repeatForever(), value: pulse)
            default:
                LibraryThumbnail(item: LibraryCatalog.dailyItem(), longSide: 420)
                    .washed()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.26), radius: 16, y: 10)
                    .offset(y: pulse ? -5 : 0)
                    .animation(.easeInOut(duration: 2.5).repeatForever(), value: pulse)
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 62, height: 62)
                    .background(Theme.accent, in: Circle())
                    .shadow(color: Theme.accentDeep.opacity(0.34), radius: 9, y: 6)
                    .offset(x: 80, y: 68)
            }
        }
        .id(step)
        .transition(.opacity)
    }
}
