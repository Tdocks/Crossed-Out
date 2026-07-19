import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @AppStorage("co.appearance") private var appearanceRaw: String = COAppearance.system.rawValue
    @AppStorage("co.reminder.enabled") private var reminderEnabled: Bool = false
    @AppStorage("co.reminder.hour") private var reminderHour: Int = 8
    @AppStorage("co.reminder.minute") private var reminderMinute: Int = 0
    @AppStorage("co.streakReminder.enabled") private var streakReminderEnabled: Bool = false
    @AppStorage("co.streakReminder.hour") private var streakReminderHour: Int = 20
    @AppStorage("co.streakReminder.minute") private var streakReminderMinute: Int = 0

    @State private var firstName: String = ""
    @State private var need: String = ""
    @State private var focus: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var presentedLegalDoc: LegalDoc?
    @State private var showPlusPaywall = false
    @ObservedObject private var subscriptions = SubscriptionService.shared

    private let translations = ["BSB", "WEB", "KJV"]

    private var hasProfileChanges: Bool {
        firstName != appState.profile.firstName ||
        need != appState.profile.need ||
        focus != Set(appState.profile.focusAreas)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .padding(.top, 8)

                profileSection
                subscriptionSection
                preferencesSection
                aboutSection
                accountSection

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncFromProfile)
        .sheet(isPresented: $showPlusPaywall) {
            PlusPaywallView()
        }
    }

    private func syncFromProfile() {
        firstName = appState.profile.firstName
        need = appState.profile.need
        focus = Set(appState.profile.focusAreas)
    }

    // MARK: - Section Caption

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.coUI(11, weight: .medium))
            .foregroundColor(.coInkTertiary)
            .tracking(1.2)
            .padding(.leading, 4)
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("PROFILE")

            COCard {
                VStack(alignment: .leading, spacing: 20) {
                    labeledField(label: "First name", text: $firstName, placeholder: "Your name")

                    CODivider()

                    labeledField(label: "What you need right now", text: $need,
                                 placeholder: "Peace, direction, strength…")

                    CODivider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus areas")
                            .font(.coUI(13, weight: .medium))
                            .foregroundColor(.coInkTertiary)

                        COFlowLayout(hSpacing: 10, vSpacing: 10) {
                            ForEach(MockData.focusAreas) { area in
                                COChip(text: area.name, selected: focus.contains(area.name)) {
                                    toggleFocus(area.name)
                                }
                            }
                        }
                    }
                }
            }

            if hasProfileChanges {
                COPrimaryButton(title: "Save") {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    appState.updateProfile(firstName: firstName, need: need, focus: Array(focus))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: hasProfileChanges)
    }

    private func labeledField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.coUI(13, weight: .medium))
                .foregroundColor(.coInkTertiary)
            TextField(placeholder, text: text)
                .font(.coUI(16))
                .foregroundColor(.coInk)
        }
    }

    private func toggleFocus(_ name: String) {
        if focus.contains(name) {
            focus.remove(name)
        } else {
            focus.insert(name)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("CROSSED OUT PLUS")

            COCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.isPlus || subscriptions.effectiveIsPlus ? "Plus is active" : "Free plan")
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text(
                                appState.isPlus || subscriptions.effectiveIsPlus
                                ? "Up to \(PlusProducts.plusKyraDailyLimit) Kyra messages / day."
                                : "\(PlusProducts.freeKyraDailyLimit) Kyra messages / day. Upgrade for more room."
                            )
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                        }
                        Spacer()
                        if !(appState.isPlus || subscriptions.effectiveIsPlus) {
                            Button("Upgrade") { showPlusPaywall = true }
                                .font(.coUI(14, weight: .semibold))
                                .foregroundColor(.coCrossRed)
                        }
                    }

                    Button {
                        Task {
                            await subscriptions.restore()
                            await appState.refreshPlusStatus()
                        }
                    } label: {
                        Text("Restore purchases")
                            .font(.coUI(13, weight: .medium))
                            .foregroundColor(.coInkSecondary)
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    Toggle(isOn: Binding(
                        get: { subscriptions.debugForcePlus },
                        set: {
                            subscriptions.debugForcePlus = $0
                            appState.refreshPlusFromSubscriptions()
                        }
                    )) {
                        Text("Debug: simulate Plus")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    .tint(.coOlive)
                    #endif
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("PREFERENCES")

            COCard {
                VStack(alignment: .leading, spacing: 20) {
                    translationRow
                    CODivider()
                    appearanceRow
                    CODivider()
                    reminderRow
                    CODivider()
                    streakReminderRow
                }
            }
        }
    }

    private var translationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Translation")
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
            }
            Spacer()
            Picker("Translation", selection: Binding(
                get: { appState.profile.translation },
                set: { appState.updateProfile(translation: $0) }
            )) {
                ForEach(translations, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
    }

    private var appearanceRow: some View {
        HStack {
            Text("Appearance")
                .font(.coUI(15))
                .foregroundColor(.coInk)
            Spacer()
            Menu {
                ForEach(COAppearance.allCases) { option in
                    Button {
                        appearanceRaw = option.rawValue
                    } label: {
                        if appearanceRaw == option.rawValue {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(COAppearance(rawValue: appearanceRaw)?.label ?? "System")
                        .font(.coUI(15))
                        .foregroundColor(.coInkSecondary)
                    COIcon(.chevronRight, size: 12, color: .coInkTertiary)
                        .rotationEffect(.degrees(90))
                }
            }
        }
    }

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: reminderEnabledBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder")
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                    Text("A gentle nudge to spend a moment with God.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }
            }
            .tint(.coCrossRed)

            if reminderEnabled {
                DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: reminderEnabled)
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { newValue in
                reminderEnabled = newValue
                if newValue {
                    Task {
                        let authorized = await ReminderService.schedule(hour: reminderHour, minute: reminderMinute)
                        if !authorized {
                            await MainActor.run { reminderEnabled = false }
                        }
                    }
                } else {
                    ReminderService.cancel()
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = reminderHour
                comps.minute = reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = comps.hour ?? 8
                reminderMinute = comps.minute ?? 0
                if reminderEnabled {
                    Task { await ReminderService.schedule(hour: reminderHour, minute: reminderMinute) }
                }
            }
        )
    }

    private var streakReminderRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: streakReminderEnabledBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak nudge")
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                    Text("An evening reminder to keep your flame lit.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }
            }
            .tint(.coCrossRed)

            if streakReminderEnabled {
                DatePicker("Time", selection: streakReminderTimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: streakReminderEnabled)
    }

    private var streakReminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { streakReminderEnabled },
            set: { newValue in
                streakReminderEnabled = newValue
                if newValue {
                    Task {
                        let authorized = await ReminderService.scheduleStreakNudge(
                            hour: streakReminderHour, minute: streakReminderMinute
                        )
                        if !authorized {
                            await MainActor.run { streakReminderEnabled = false }
                        }
                    }
                } else {
                    ReminderService.cancelStreakNudge()
                }
            }
        )
    }

    private var streakReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = streakReminderHour
                comps.minute = streakReminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                streakReminderHour = comps.hour ?? 20
                streakReminderMinute = comps.minute ?? 0
                if streakReminderEnabled {
                    Task {
                        await ReminderService.scheduleStreakNudge(
                            hour: streakReminderHour, minute: streakReminderMinute
                        )
                    }
                }
            }
        )
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("ABOUT")

            COCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Version")
                            .font(.coUI(15))
                            .foregroundColor(.coInk)
                        Spacer()
                        Text(appVersion)
                            .font(.coUI(14))
                            .foregroundColor(.coInkTertiary)
                    }
                    CODivider()
                    legalRow(title: LegalDocuments.termsTitle, doc: .terms)
                    CODivider()
                    legalRow(title: LegalDocuments.privacyTitle, doc: .privacy)
                    CODivider()
                    Text("Crossed Out — Scripture for Real Life")
                        .font(.coUIItalic(13))
                        .foregroundColor(.coInkTertiary)
                }
            }
        }
        .sheet(item: $presentedLegalDoc) { LegalDocView(doc: $0) }
    }

    private func legalRow(title: String, doc: LegalDoc) -> some View {
        Button {
            presentedLegalDoc = doc
        } label: {
            HStack {
                Text(title)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                Spacer()
                COIcon(.chevronRight, size: 12, color: .coInkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCaption("ACCOUNT")

            COCard {
                VStack(alignment: .leading, spacing: 12) {
                    if isDeletingAccount {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Deleting your account…")
                                .font(.coUI(14))
                                .foregroundColor(.coInkTertiary)
                        }
                    } else {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Text("Delete Account")
                                    .font(.coUI(15, weight: .medium))
                                    .foregroundColor(.coCrossRed)
                                Spacer()
                                COIcon(.chevronRight, size: 12, color: .coCrossRed)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete your account? This permanently removes your profile, streaks, highlights, notes, and prayers. This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            let success = await SupabaseService.shared.deleteAccount()
            isDeletingAccount = false
            if success {
                for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("co.") {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                appState.signOutAndReset()
            }
        }
    }
}

// MARK: - Appearance

enum COAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
