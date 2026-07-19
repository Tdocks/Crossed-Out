import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

// MARK: - Found church (a real-world church from Apple Maps)

struct FoundChurch: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phone: String?
    let url: URL?
    var distanceMeters: CLLocationDistance?

    static func from(_ item: MKMapItem, from origin: CLLocation) -> FoundChurch {
        let pm = item.placemark
        let parts = [pm.thoroughfare, pm.locality, pm.administrativeArea].compactMap { $0 }
        let dest = CLLocation(latitude: pm.coordinate.latitude, longitude: pm.coordinate.longitude)
        return FoundChurch(
            name: item.name ?? "Church",
            coordinate: pm.coordinate,
            address: parts.joined(separator: ", "),
            phone: item.phoneNumber,
            url: item.url,
            distanceMeters: origin.distance(from: dest)
        )
    }

    var distanceLabel: String {
        guard let m = distanceMeters else { return "" }
        let miles = m / 1609.34
        return miles < 0.1 ? "nearby" : String(format: "%.1f mi", miles)
    }
}

private enum FinderMode: String, CaseIterable { case map = "Map", list = "List" }

// MARK: - Church Finder

struct ChurchFinderView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var locationManager = ChurchLocationManager()

    @State private var mode: FinderMode = .map
    @State private var searchText = ""
    @State private var radiusMiles: Double = 10
    @State private var results: [FoundChurch] = []
    @State private var searching = false
    @State private var searchError: String?

    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedID: UUID?
    @State private var detailChurch: FoundChurch?

    // Curated "streaming" churches (existing membership/save mechanic)
    @State private var savedChurchIDs: Set<UUID> = []
    @State private var joinedChurchIDs: Set<UUID> = []

    private let radiusOptions: [Double] = [5, 10, 25, 50]

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if mode == .map { mapSection } else { listSection }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detailChurch) { church in
            FoundChurchDetailSheet(church: church, streamingMatch: matchedStreaming(church))
                .presentationDetents([.medium, .large])
        }
        .task {
            await loadSavedChurchIDs()
            await loadJoinedChurchIDs()
            if locationManager.isAuthorized { locationManager.request() }
        }
        .onReceive(locationManager.$location) { newValue in
            guard let loc = newValue else { return }
            Task { await runSearch(center: loc.coordinate) }
        }
        .onChange(of: selectedID) { _, newValue in
            if let id = newValue, let church = results.first(where: { $0.id == id }) {
                detailChurch = church
            }
        }
    }

    // MARK: Header (title, search, radius, mode)

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Find a Church")
                .font(.coDisplay(26, weight: .semibold))
                .foregroundColor(.coInk)
                .padding(.top, 8)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    COIcon(.search, size: 16, color: .coInkTertiary)
                    TextField("Search a city or ZIP", text: $searchText)
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await searchTypedLocation() } }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            COIcon(.crossOut, size: 14, color: .coInkTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )

                Button { locateMe() } label: {
                    COIcon(.mapPin, size: 18, color: .coCrossRed)
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.coCrossRed.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(radiusOptions, id: \.self) { r in
                        COChip(text: "\(Int(r)) mi", selected: radiusMiles == r) {
                            guard radiusMiles != r else { return }
                            radiusMiles = r
                            if let c = lastCenter { Task { await runSearch(center: c) } }
                        }
                    }
                    Spacer(minLength: 0)
                    Picker("", selection: $mode) {
                        ForEach(FinderMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Search

    @State private var lastCenter: CLLocationCoordinate2D?

    private func locateMe() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if locationManager.isDenied {
            searchError = "Location is off. Enable it in Settings, or search a city or ZIP above."
            return
        }
        searching = true
        locationManager.request()
    }

    private func searchTypedLocation() async {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searching = true
        searchError = nil
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.geocodeAddressString(q),
           let loc = placemarks.first?.location {
            await runSearch(center: loc.coordinate)
        } else {
            searching = false
            searchError = "Couldn't find “\(q)”. Try a city or ZIP."
        }
    }

    private func runSearch(center: CLLocationCoordinate2D) async {
        searching = true
        searchError = nil
        lastCenter = center
        let meters = radiusMiles * 1609.34
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "church"
        request.region = MKCoordinateRegion(
            center: center, latitudinalMeters: meters * 2, longitudinalMeters: meters * 2)
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        do {
            let response = try await MKLocalSearch(request: request).start()
            let found = response.mapItems
                .map { FoundChurch.from($0, from: origin) }
                .filter { ($0.distanceMeters ?? .greatestFiniteMagnitude) <= meters }
                .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            results = found
            withAnimation(.easeInOut(duration: 0.3)) {
                camera = .region(MKCoordinateRegion(
                    center: center, latitudinalMeters: meters * 2.2, longitudinalMeters: meters * 2.2))
            }
        } catch {
            results = []
            searchError = "Couldn't search here. Check your connection and try again."
        }
        searching = false
    }

    /// Cross-reference a found church against the curated streaming churches.
    private func matchedStreaming(_ found: FoundChurch) -> Church? {
        appState.churches.first { curated in
            found.name.localizedCaseInsensitiveContains(curated.name)
                || curated.name.localizedCaseInsensitiveContains(found.name)
        }
    }

    // MARK: Map mode

    private var mapSection: some View {
        Map(position: $camera, selection: $selectedID) {
            ForEach(results) { church in
                Marker(church.name, systemImage: "cross.fill", coordinate: church.coordinate)
                    .tint(Color.coCrossRed)
                    .tag(church.id)
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .top) { mapStatusPill }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var mapStatusPill: some View {
        let text: String? = {
            if searching { return "Searching…" }
            if let searchError { return searchError }
            if lastCenter == nil { return "Search a place or tap the location button" }
            if results.isEmpty { return "No churches within \(Int(radiusMiles)) mi — try a wider radius" }
            return nil
        }()
        if let text {
            HStack(spacing: 8) {
                if searching { ProgressView().tint(.coInk).scaleEffect(0.8) }
                Text(text)
                    .font(.coUI(12, weight: .medium))
                    .foregroundColor(.coInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 10)
        }
    }

    // MARK: List mode

    private var listSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                nearYouSection
                streamingSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 90)
        }
    }

    private var nearYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            COSectionHeader(title: "Near You")
            if searching {
                loadingCard("Finding churches near you…")
            } else if let searchError {
                infoCard(searchError)
            } else if results.isEmpty {
                infoCard(lastCenter == nil
                    ? "Tap the location button or search a city to find churches near you."
                    : "No churches found within \(Int(radiusMiles)) miles. Try a wider radius.")
            } else {
                VStack(spacing: 10) {
                    ForEach(results) { church in foundChurchRow(church) }
                }
            }
        }
    }

    private func foundChurchRow(_ church: FoundChurch) -> some View {
        Button { detailChurch = church } label: {
            COCard {
                HStack(spacing: 12) {
                    churchGlyph
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(church.name)
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                                .lineLimit(1)
                            if matchedStreaming(church) != nil { streamsTag }
                        }
                        if !church.address.isEmpty {
                            Text(church.address)
                                .font(.coUI(12))
                                .foregroundColor(.coInkTertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(church.distanceLabel)
                        .font(.coUI(12, weight: .medium))
                        .foregroundColor(.coInkSecondary)
                    COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var churchGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.coCrossRed.opacity(0.12))
            COIcon(.church, size: 20, color: .coCrossRed)
        }
        .frame(width: 44, height: 44)
    }

    private var streamsTag: some View {
        Text("STREAMS")
            .font(.coUI(9, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(.coGold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(Color.coGold.opacity(0.5), lineWidth: 1))
    }

    private func loadingCard(_ text: String) -> some View {
        COCard {
            HStack(spacing: 10) {
                ProgressView()
                Text(text).font(.coUI(13)).foregroundColor(.coInkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoCard(_ text: String) -> some View {
        COCard {
            Text(text)
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Streaming (curated) churches

    private var streamingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            COSectionHeader(title: "Streaming on Crossed Out")
            Text("Churches you can watch live in the app.")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            if appState.churches.isEmpty {
                infoCard("Streaming churches will appear here.")
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.churches) { church in streamingChurchRow(church) }
                }
            }
            footer
        }
    }

    private func streamingChurchRow(_ church: Church) -> some View {
        let isSaved = savedChurchIDs.contains(church.id)
        return COCard {
            HStack(spacing: 12) {
                monogram(for: church)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(church.name)
                            .font(.coUI(15, weight: .semibold))
                            .foregroundColor(.coInk)
                            .lineLimit(1)
                        if church.isLive {
                            Text("LIVE")
                                .font(.coUI(9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.coCrossRed))
                        }
                    }
                    Text(church.city)
                        .font(.coUI(12))
                        .foregroundColor(.coInkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                joinButton(for: church)
                Button { toggleSaved(church) } label: {
                    COIcon(.heart, size: 18, color: isSaved ? .coCrossRed : .coInkTertiary)
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func joinButton(for church: Church) -> some View {
        let joined = joinedChurchIDs.contains(church.id)
        return Button { toggleJoined(church) } label: {
            Text(joined ? "Joined" : "Join")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(joined ? .coOlive : .white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(joined ? Color.clear : Color.coCrossRed))
                .overlay(Capsule().strokeBorder(joined ? Color.coOlive.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func monogram(for church: Church) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.coOlive.opacity(0.12))
            Text(String(church.name.prefix(1)))
                .font(.coDisplay(20, weight: .semibold))
                .foregroundColor(.coOlive)
        }
        .frame(width: 44, height: 44)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Can't find your church?")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            Button { openSuggestChurchEmail() } label: {
                Text("Suggest a Church")
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coCrossRed)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: Membership / save

    private func loadSavedChurchIDs() async {
        guard let ids = try? await SupabaseService.shared.fetchSavedChurchIDs() else { return }
        await MainActor.run { savedChurchIDs = ids }
    }

    private func loadJoinedChurchIDs() async {
        guard let memberships = try? await SupabaseService.shared.fetchChurchMemberships() else { return }
        await MainActor.run { joinedChurchIDs = Set(memberships.map { $0.churchID }) }
    }

    private func toggleSaved(_ church: Church) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let id = church.id
        let newValue = !savedChurchIDs.contains(id)
        withAnimation(.easeOut(duration: 0.2)) {
            if newValue { savedChurchIDs.insert(id) } else { savedChurchIDs.remove(id) }
        }
        Task { await SupabaseService.shared.setChurchSaved(churchID: id, saved: newValue) }
    }

    private func toggleJoined(_ church: Church) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let id = church.id
        let newValue = !joinedChurchIDs.contains(id)
        withAnimation(.easeOut(duration: 0.2)) {
            if newValue { joinedChurchIDs.insert(id) } else { joinedChurchIDs.remove(id) }
        }
        Task {
            if newValue { await SupabaseService.shared.joinChurch(churchID: id) }
            else { await SupabaseService.shared.leaveChurch(churchID: id) }
        }
    }

    private func openSuggestChurchEmail() {
        let subject = "Suggest a Church".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Suggest"
        guard let url = URL(string: "mailto:tdoxwell@icloud.com?subject=\(subject)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Found church detail

private struct FoundChurchDetailSheet: View {
    let church: FoundChurch
    let streamingMatch: Church?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(church.name)
                    .font(.coDisplay(24, weight: .semibold))
                    .foregroundColor(.coInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !church.address.isEmpty {
                    Text(church.address)
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                }
                if !church.distanceLabel.isEmpty {
                    Text("\(church.distanceLabel) away")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }
            }
            .padding(.top, 6)

            if streamingMatch != nil {
                COCard {
                    HStack(spacing: 12) {
                        COIcon(.play, size: 18, color: .coGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streams live on Crossed Out")
                                .font(.coUI(14, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("Watch this church's services in the Attend tab.")
                                .font(.coUI(12))
                                .foregroundColor(.coInkSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            VStack(spacing: 10) {
                COPrimaryButton(title: "Directions") { openDirections() }
                HStack(spacing: 10) {
                    if church.phone != nil { secondaryButton("Call") { call() } }
                    if church.url != nil { secondaryButton("Website") { if let u = church.url { openURL(u) } } }
                }
            }

            Spacer()
            COSecondaryButton(title: "Close") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.coUI(14, weight: .medium))
                .foregroundColor(.coInkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: church.coordinate))
        item.name = church.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func call() {
        guard let phone = church.phone else { return }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:\(digits)") { UIApplication.shared.open(url) }
    }
}

#Preview {
    NavigationStack {
        ChurchFinderView()
            .environmentObject(AppState())
    }
}
