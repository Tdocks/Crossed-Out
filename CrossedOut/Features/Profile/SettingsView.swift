import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @AppStorage("co.appearance") private var appearanceRaw: String = COAppearance.system.rawValue
    @AppStorage("co.reminder.enabled") private var reminderEnabled: Bool = false
    @AppStorage("co.reminder.hour") private var reminderHour: Int = 8
    @AppStorage("co.reminder.minute") private var reminderMinute: Int = 0

    @State private var firstName: String = ""
    @State private var need: String = ""
    @State private var focus: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false

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

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                                  alignment: .leading, spacing: 10) {
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
                    Text("Crossed Out — Scripture for Real Life")
                        .font(.coUIItalic(13))
                        .foregroundColor(.coInkTertiary)
                }
            }
        }
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
