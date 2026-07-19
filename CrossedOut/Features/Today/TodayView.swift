import SwiftUI
import AVFoundation

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()
    @State private var showCheckIn = false
    @State private var crossedToday: Bool = UserDefaults.standard.bool(forKey: TodayView.devoCrossedKey)
    @State private var showPraySheet = false
    @State private var prayedToday: Bool = UserDefaults.standard.bool(forKey: TodayView.prayedTodayKey)
    @State private var actionDone: Bool = UserDefaults.standard.bool(forKey: TodayView.actionDoneKey)
    @State private var verseFeedbackGiven: String?
    @State private var rerolling = false
    @State private var todayDevotional: Devotional?
    @State private var devotionalLoading = true
    @StateObject private var speechController = TodaySpeechController()

    private enum TodayRoute: Hashable { case bible, kyra, settings, devotionals, devotionalDetail }

    private static var prayedTodayKey: String {
        "co.prayedToday." + SupabaseService.dayString(Date())
    }

    private static var actionDoneKey: String {
        "co.actionDone." + SupabaseService.dayString(Date())
    }

    private static var devoCrossedKey: String {
        "co.devoCrossed." + SupabaseService.dayString(Date())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if appState.isOffline {
                        offlineBanner
                    }
                    greetingBlock
                    dailyDevotionalRow
                    verseCard
                    focusCard
                    actionCard
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
                case .kyra: KyraView(
                    contextRef: appState.todayEntry.verse.ref.display,
                    contextText: appState.todayEntry.verse.text
                )
                case .settings: SettingsView()
                case .devotionals: DevotionalsHubView().hidesTabBar()
                case .devotionalDetail:
                    Group {
                        if let d = todayDevotional {
                            DevotionalDetailView(devotional: d)
                        } else {
                            DevotionalsHubView()
                        }
                    }
                    .hidesTabBar()
                }
            }
            .task {
                if todayDevotional == nil {
                    todayDevotional = await SupabaseService.shared.fetchTodayDevotional()
                }
                devotionalLoading = false
            }
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInSheet()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPraySheet) {
            PrayerSheet(text: TodayPrayer.text(
                focus: appState.profile.focusAreas.first,
                mood: appState.checkInMood
            )) {
                withAnimation { prayedToday = true }
                UserDefaults.standard.set(true, forKey: TodayView.prayedTodayKey)
                Task { await SupabaseService.shared.recordCompletion(kind: "prayer") }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            COAvatar(initials: avatarInitial, size: 40)
            Spacer(minLength: 8)
            Text(dateLine)
                .font(.coUI(12, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.coInkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Button { path.append(TodayRoute.settings) } label: {
                COIcon(.bell, size: 20, color: .coInkSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    /// First letter of the user's real first name (never a mock initial).
    private var avatarInitial: String {
        let first = appState.profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).first
        return first.map(String.init) ?? "•"
    }

    private var dateLine: String {
        let now = Date()
        let wd = DateFormatter(); wd.dateFormat = "EEEE"
        let md = DateFormatter(); md.dateFormat = "MMM d"
        let weekday = wd.string(from: now).uppercased()
        let day = md.string(from: now).uppercased()
        return "\(weekday) • \(day) • DAY \(appState.profile.dayNumber)"
    }

    // MARK: Offline Banner

    /// A quiet hairline notice shown only when every bootstrap fetch failed,
    /// reassuring the user that saved content is still safe to use.
    private var offlineBanner: some View {
        HStack(spacing: 6) {
            COIcon(.leaf, size: 11, color: .coInkTertiary)
            Text("Offline — showing your saved content.")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { CODivider() }
    }

    // MARK: Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(timeGreeting), \(appState.profile.firstName).")
                .font(.coUI(14))
                .foregroundColor(.coInkSecondary)
            Text("What are you carrying today?")
                .font(.coDisplay(30, weight: .semibold))
                .foregroundColor(.coInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Button { showCheckIn = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    (Text("You said: ")
                        .font(.coUI(15))
                        .foregroundColor(.coInkSecondary)
                     + Text(displayedNeed)
                        .font(.coUIItalic(15))
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

    /// Deterministic time-of-day greeting (the old copy said "Good morning"
    /// all day).
    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// The user's actual onboarding/settings answer. The fallback is the
    /// same neutral default onboarding writes for an empty answer — never
    /// mock copy.
    private var displayedNeed: String {
        appState.profile.need.isEmpty ? "I want to grow closer to God." : appState.profile.need
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
                    .font(.coScripture(22))
                    .foregroundColor(.coInk)
                    .lineSpacing(10)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                HStack {
                    Spacer()
                    Text(appState.todayEntry.verse.translation)
                        .font(.coUI(10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.coInkTertiary)
                }
                if let reason = appState.todayVerseReason {
                    verseReasonBlock(reason)
                }
                CODivider().padding(.vertical, 6)
                verseActions
            }
        }
    }

    /// Quiet "why this verse" line from the personalization engine, plus two
    /// tasteful feedback affordances. Only rendered when the engine actually
    /// produced a recommendation — otherwise this whole block is absent, no
    /// placeholder, no error state.
    private func verseReasonBlock(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reason)
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if appState.todayVerseBook != nil {
                HStack(spacing: 16) {
                    verseFeedbackButton(title: "This spoke to me", signal: "spoke")
                    verseFeedbackButton(title: "Not for today", signal: "not_today")
                }
                Button {
                    guard !rerolling else { return }
                    rerolling = true
                    Task {
                        await appState.rerollTodayVerse()
                        withAnimation(.easeOut(duration: 0.2)) { verseFeedbackGiven = nil }
                        rerolling = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        COIcon(.leaf, size: 12, color: .coOlive)
                        Text(rerolling ? "Finding another…" : "Show me another verse")
                            .font(.coUI(11, weight: .medium))
                            .foregroundColor(.coOlive)
                    }
                }
                .buttonStyle(.plain)
                .disabled(rerolling)
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    private func verseFeedbackButton(title: String, signal: String) -> some View {
        let given = verseFeedbackGiven == signal
        return Button {
            // Feedback is attributed by verse reference (book/chapter/verse),
            // not curated_verse_id, so it works for AI-tagged verses too
            // (record_verse_feedback's signature per migration 0013).
            guard let book = appState.todayVerseBook,
                  let chapter = appState.todayVerseChapter,
                  let verse = appState.todayVerseVerse else { return }
            withAnimation(.easeOut(duration: 0.2)) { verseFeedbackGiven = signal }
            Task {
                await SupabaseService.shared.sendVerseFeedback(
                    book: book, chapter: chapter, verse: verse, signal: signal
                )
            }
        } label: {
            Text(given ? "Thank you" : title)
                .font(.coUI(11, weight: .medium))
                .foregroundColor(given ? .coCrossRed : .coInkTertiary)
        }
        .buttonStyle(.plain)
        .disabled(verseFeedbackGiven != nil)
    }

    private var verseActions: some View {
        HStack(spacing: 0) {
            actionButton(.bible, "Read") { path.append(TodayRoute.bible) }
            listenAction
            actionButton(.journal, "Reflect") {
                path.append(TodayRoute.kyra)
                Task { await SupabaseService.shared.recordCompletion(kind: "reflection") }
            }
            prayAction
        }
    }

    private var listenAction: some View {
        Button {
            if speechController.isSpeaking {
                speechController.stop()
            } else {
                speechController.speak(appState.todayEntry.verse.text)
                Task { await SupabaseService.shared.recordCompletion(kind: "scripture") }
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

    // MARK: Today's Focus — the "understand" step

    private var focusCard: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    COIcon(.flame, size: 18, color: .coGold)
                    Text(focusTitle)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Spacer()
                }
                Text("What it means")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
                    .padding(.top, 2)
                Text(contextText)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The user's primary focus area (from onboarding/settings). Falls back
    /// to plain product copy when none is set yet — never mock data.
    private var focusTitle: String {
        appState.profile.focusAreas.first ?? "Your journey"
    }

    /// The understand step: curated pastoral context for today's verse
    /// (curated_verses.theme_summary via the recommend engine). For an
    /// AI-tagged verse with no curated row, falls back to a deterministic
    /// focus-based line.
    private var contextText: String {
        if let context = appState.todayVerseContext, !context.isEmpty {
            return context
        }
        if let focus = appState.profile.focusAreas.first {
            return "This verse was chosen for where you are — \(focus.lowercased()). Read it slowly and let one phrase stay with you today."
        }
        return "Read it slowly, twice, and let one phrase stay with you today."
    }

    // MARK: One Small Step — the "act" step

    /// Today's deterministic practical action (today_practice_action RPC,
    /// migration 0025). Hidden entirely when unavailable (signed out,
    /// offline before first load, migration not applied) — no placeholder.
    @ViewBuilder
    private var actionCard: some View {
        if let action = appState.todayAction {
            COCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        COIcon(.checkCircle, size: 16, color: .coOlive)
                        Text("ONE SMALL STEP")
                            .font(.coUI(11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundColor(.coInkTertiary)
                        Spacer()
                    }
                    Text(action.body)
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        guard !actionDone else { return }
                        withAnimation(.easeOut(duration: 0.35)) { actionDone = true }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        UserDefaults.standard.set(true, forKey: TodayView.actionDoneKey)
                        Task { await SupabaseService.shared.recordCompletion(kind: "action") }
                    } label: {
                        HStack(spacing: 8) {
                            COIcon(actionDone ? .checkCircle : .crossOut, size: 15,
                                   color: actionDone ? .coCrossRed : .coInkSecondary)
                            CrossOutText("I did this", crossed: actionDone, size: 13)
                            if actionDone {
                                Text("Well walked.")
                                    .font(.coUI(12))
                                    .foregroundColor(.coInkTertiary)
                                    .transition(.opacity)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: Daily Devotional (thin row at the top of the stack)

    /// Compact single-row entry to the daily devotional, pinned above the
    /// verse of the day. Tap opens the full devotional; the leading circle
    /// is the cross-off (records daily_completions kind='devotional',
    /// persisted per day). Replaces the old mid-stack card + cross-off row.
    private var dailyDevotionalRow: some View {
        COCard(padding: 12) {
            HStack(spacing: 12) {
                Button {
                    toggleDevotionalCrossed()
                } label: {
                    COIcon(crossedToday ? .checkCircle : .crossOut, size: 20,
                           color: crossedToday ? .coCrossRed : .coInkSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    path.append(todayDevotional != nil ? TodayRoute.devotionalDetail : TodayRoute.devotionals)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DAILY DEVOTIONAL")
                                .font(.coUI(10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundColor(.coInkTertiary)
                            if let d = todayDevotional {
                                CrossOutText(d.title, crossed: crossedToday, size: 14)
                                    .lineLimit(1)
                            } else if devotionalLoading {
                                Text("Preparing today's…")
                                    .font(.coUI(14))
                                    .foregroundColor(.coInkTertiary)
                            } else {
                                Text("Open devotionals")
                                    .font(.coUI(14))
                                    .foregroundColor(.coInkSecondary)
                            }
                        }
                        Spacer()
                        COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleDevotionalCrossed() {
        withAnimation { crossedToday.toggle() }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        UserDefaults.standard.set(crossedToday, forKey: TodayView.devoCrossedKey)
        if crossedToday {
            Task { await SupabaseService.shared.recordCompletion(kind: "devotional") }
        }
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

/// Deterministic daily prayer, composed from today's mood + the user's
/// primary focus area. Plain templates, no AI — replaces the old hardcoded
/// mock prayer.
private enum TodayPrayer {
    static func text(focus: String?, mood: Mood?) -> String {
        var lines: [String] = [opening(for: mood)]
        if let focus, !focus.isEmpty {
            lines.append("Meet me today in \(focus.lowercased()). Give me wisdom for the next small step, and the trust to leave what I can't control with You.")
        } else {
            lines.append("Give me wisdom for the next small step, and the trust to leave what I can't control with You.")
        }
        lines.append("Not by my strength, but Yours. Amen.")
        return lines.joined(separator: " ")
    }

    private static func opening(for mood: Mood?) -> String {
        switch mood {
        case .peaceful: return "Father, thank You for the quiet You've given me today."
        case .anxious: return "Father, You see the worry I'm carrying today."
        case .discouraged: return "Father, today feels heavy, and my hope is running thin."
        case .motivated: return "Father, thank You for the energy You've given me today — help me spend it well."
        case .angry: return "Father, something in me is burning today. Cool it with Your patience."
        case .lonely: return "Father, I feel alone today — remind me that You are near."
        case .confused: return "Father, I can't see the way clearly today."
        case .grateful: return "Father, my heart is full today — thank You."
        case .tempted: return "Father, You know what's pulling at me today. Be my strength."
        case .overwhelmed: return "Father, there is more in front of me today than I can hold."
        case .hopeful: return "Father, thank You for the hope stirring in me today."
        case .grieving: return "Father, You see my grief, and You keep count of every tear."
        case nil: return "Father, thank You for being with me right here, right now."
        }
    }
}

private struct PrayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let text: String
    let onAmen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A PRAYER FOR TODAY")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)
            Text(text)
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
    private let voice: AVSpeechSynthesisVoice?

    override init() {
        voice = Self.bestAvailableVoice()
        super.init()
        synthesizer.delegate = self
    }

    /// Picks the best-sounding en-US voice installed on-device: prefers the
    /// highest synthesis quality tier available (premium, then enhanced,
    /// then whatever default exists), and within a tier prefers a short list
    /// of natural-sounding names.
    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let preferredNames = ["Ava", "Zoe", "Samantha"]
        let enUSVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }

        func best(in candidates: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            for name in preferredNames {
                if let match = candidates.first(where: { $0.name.contains(name) }) {
                    return match
                }
            }
            return candidates.first
        }

        let premium = enUSVoices.filter { $0.quality == .premium }
        let enhanced = enUSVoices.filter { $0.quality == .enhanced }

        return best(in: premium)
            ?? best(in: enhanced)
            ?? best(in: enUSVoices)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        // The silent switch otherwise mutes AVSpeechSynthesizer on-device;
        // .playback keeps devotional audio audible even when muted.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
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
