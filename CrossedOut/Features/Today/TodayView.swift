import SwiftUI
import AVFoundation

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()
    @State private var showCheckIn = false
    @State private var crossedToday = false
    @State private var showPraySheet = false
    @State private var prayedToday: Bool = UserDefaults.standard.bool(forKey: TodayView.prayedTodayKey)
    @StateObject private var speechController = TodaySpeechController()

    private enum TodayRoute: Hashable { case bible, kyra }

    private static var prayedTodayKey: String {
        "co.prayedToday." + SupabaseService.dayString(Date())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    greetingBlock
                    verseCard
                    focusCard
                    crossOutRow
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .bible: BibleReaderView(isPushed: true)
                case .kyra: KyraView()
                }
            }
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInSheet()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPraySheet) {
            PrayerSheet {
                withAnimation { prayedToday = true }
                UserDefaults.standard.set(true, forKey: TodayView.prayedTodayKey)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            COAvatar(initials: "T", size: 40)
            Spacer(minLength: 8)
            Text(dateLine)
                .font(.coUI(12, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.coInkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button { } label: {
                COIcon(.bell, size: 20, color: .coInkSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var dateLine: String {
        let now = Date()
        let wd = DateFormatter(); wd.dateFormat = "EEEE"
        let md = DateFormatter(); md.dateFormat = "MMM d"
        let weekday = wd.string(from: now).uppercased()
        let day = md.string(from: now).uppercased()
        return "\(weekday) • \(day) • DAY \(appState.profile.dayNumber)"
    }

    // MARK: Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Good morning, \(appState.profile.firstName).")
                .font(.coUI(14))
                .foregroundColor(.coInkSecondary)
            Text(appState.todayEntry.carryingPrompt)
                .font(.coDisplay(30, weight: .semibold))
                .foregroundColor(.coInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Button { showCheckIn = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    (Text("You said: ")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                     + Text(appState.todayEntry.userNeed)
                        .font(.coUIItalic(14))
                        .foregroundColor(.coCrossRed))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    COIcon(.chevronRight, size: 12, color: .coCrossRed)
                    if let mood = appState.checkInMood {
                        moodChip(mood)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .animation(.easeOut(duration: 0.3), value: appState.checkInMood)
        }
    }

    private func moodChip(_ mood: Mood) -> some View {
        Text(mood.label)
            .font(.coUI(11, weight: .medium))
            .foregroundColor(.coCrossRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.coCrossRed.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.coCrossRed.opacity(0.3), lineWidth: 1))
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: Today's Verse

    private var verseCard: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY'S VERSE")
                    .font(.coUI(11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(.coInkTertiary)
                Text(appState.todayEntry.verse.ref.display)
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coInk)
                Text(appState.todayEntry.verse.text)
                    .font(.coScripture(20))
                    .foregroundColor(.coInk)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                HStack {
                    Spacer()
                    Text(appState.todayEntry.verse.translation)
                        .font(.coUI(10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.coInkTertiary)
                }
                CODivider().padding(.vertical, 6)
                verseActions
            }
        }
    }

    private var verseActions: some View {
        HStack(spacing: 0) {
            actionButton(.bible, "Read") { path.append(TodayRoute.bible) }
            listenAction
            actionButton(.journal, "Reflect") { path.append(TodayRoute.kyra) }
            prayAction
        }
    }

    private var listenAction: some View {
        Button {
            if speechController.isSpeaking {
                speechController.stop()
            } else {
                speechController.speak(appState.todayEntry.verse.text)
            }
        } label: {
            VStack(spacing: 6) {
                COIcon(.music, size: 20, color: speechController.isSpeaking ? .coCrossRed : .coInkSecondary)
                Text("Listen")
                    .font(.coUI(11))
                    .foregroundColor(speechController.isSpeaking ? .coCrossRed : .coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var prayAction: some View {
        Button {
            showPraySheet = true
        } label: {
            VStack(spacing: 6) {
                COIcon(.prayer, size: 20, color: prayedToday ? .coInkTertiary : .coInkSecondary)
                CrossOutText("Pray", crossed: prayedToday, size: 11)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ icon: COIconName, _ label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                COIcon(icon, size: 20, color: .coInkSecondary)
                Text(label)
                    .font(.coUI(11))
                    .foregroundColor(.coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Today's Focus

    private var focusCard: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    COIcon(.flame, size: 18, color: .coGold)
                    Text(appState.todayEntry.focusTitle)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Spacer()
                    COIcon(.chevronRight, size: 16, color: .coInkTertiary)
                }
                Text("Why this verse?")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
                    .padding(.top, 2)
                Text(appState.todayEntry.focusWhy)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Cross Out Row

    private var crossOutRow: some View {
        Button {
            withAnimation { crossedToday.toggle() }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                COIcon(crossedToday ? .checkCircle : .crossOut, size: 18,
                       color: crossedToday ? .coCrossRed : .coInkSecondary)
                CrossOutText("Cross off today's devotional", crossed: crossedToday)
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Check-In Sheet

private struct CheckInSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How are you carrying it?")
                    .font(.coDisplay(22, weight: .semibold))
                    .foregroundColor(.coInk)
                Text("Name what you're feeling today.")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Mood.allCases) { mood in
                    COChip(text: mood.label, selected: appState.checkInMood == mood) {
                        Task { await appState.saveCheckIn(mood: mood) }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        dismiss()
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
    }
}

// MARK: - Prayer Sheet

private struct PrayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAmen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A PRAYER FOR TODAY")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)
            Text("Father, thank You that I don't have to carry the weight of my future alone. Give me wisdom in my decisions, peace in uncertainty, and trust that You are preparing something good. Amen.")
                .font(.coScripture(18, italic: true))
                .foregroundColor(.coInk)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            COPrimaryButton(title: "Amen") {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onAmen()
                dismiss()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
    }
}

// MARK: - Speech Controller

/// Wraps AVSpeechSynthesizer as an ObservableObject so a single instance can
/// be held via @StateObject and survive body re-evaluations mid-speech.
private final class TodaySpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environmentObject(AppState())
}
