import SwiftUI

struct BridgeShareView: View {
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var whyText: String = MockData.bridgeShare.whyText
    @State private var showConfirmation = false
    @State private var showVersePicker = false

    private let bridgeShare = MockData.bridgeShare

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.coPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        bridgeVisual
                        whatIWantToShareSection
                        verseSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, isModal ? 52 : 16)
                    .padding(.bottom, 24)
                }

                COPrimaryButton(title: "Send the Bridge") {
                    showConfirmation = true
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color.coPaper)
            }

            if isModal {
                dismissButton
            }
        }
        .sheet(isPresented: $showVersePicker) { VersePickerStub() }
        .fullScreenCover(isPresented: $showConfirmation) { BridgeSentConfirmationView() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Cross the Bridge")
                .font(.coDisplay(26, weight: .semibold))
                .foregroundColor(.coInk)
            Text("Share hope. Start conversations.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var bridgeVisual: some View {
        HStack {
            VStack(spacing: 8) {
                COAvatar(initials: "You", size: 44)
                Text("You")
                    .font(.coUI(11))
                    .foregroundColor(.coInkSecondary)
            }
            Spacer()
            BridgeMotif(width: 140)
            Spacer()
            VStack(spacing: 8) {
                COAvatar(initials: "J", size: 44)
                Text("\(bridgeShare.toName) · Friend")
                    .font(.coUI(11))
                    .foregroundColor(.coInkSecondary)
            }
        }
    }

    private var whatIWantToShareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What I want to share")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.coInkSecondary)
            COCard {
                TextEditor(text: $whyText)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE VERSE")
                .font(.coUI(12, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.coInkTertiary)
            COCard {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showVersePicker = true
                    } label: {
                        HStack {
                            Text(bridgeShare.verse.ref.display)
                                .font(.coUI(13, weight: .semibold))
                                .foregroundColor(.coInk)
                            Spacer()
                            COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(bridgeShare.verse.text)
                        .font(.coScripture(18))
                        .foregroundColor(.coInk)
                        .lineSpacing(7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Text("✕")
                .font(.coUI(15, weight: .medium))
                .foregroundColor(.coInkSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.coCard))
                .overlay(Circle().strokeBorder(Color.coDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.top, 8)
    }
}

private struct VersePickerStub: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                COIcon(.bible, size: 30, color: .coInkSecondary)
                Text("Verse Picker")
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                Text("Search and select a passage to share.")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Choose a Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct BridgeArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 4
        let left = CGPoint(x: r + 1, y: rect.height - r - 1)
        let right = CGPoint(x: rect.width - r - 1, y: rect.height - r - 1)
        p.move(to: left)
        p.addQuadCurve(to: right, control: CGPoint(x: rect.width / 2, y: 2))
        return p
    }
}

private struct BridgeSentConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trimEnd: CGFloat = 0

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            VStack(spacing: 20) {
                BridgeArcShape()
                    .trim(from: 0, to: trimEnd)
                    .stroke(Color.coCrossRed, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 160, height: 68)

                Text("Your bridge is on its way.")
                    .font(.coDisplay(22, weight: .semibold))
                    .foregroundColor(.coInk)

                Text("Jaden can read it without installing anything.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { trimEnd = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { dismiss() }
        }
    }
}

#Preview {
    BridgeShareView()
}

#Preview("Modal") {
    BridgeShareView(isModal: true)
}
