import Foundation

/// Paste production keys here (or via xcconfig / CI secrets). Empty = feature off.
/// Never commit real DSNs to a public fork — this file is the local seam.
enum AppSecrets {
    /// TelemetryDeck App ID (Settings → App). Empty disables analytics upload.
    static let telemetryDeckAppID = "28011B66-C508-427F-9202-26C41FB448DA"

    /// Sentry DSN. Empty disables crash reporting upload.
    static let sentryDSN = "https://908d62b660cb798dd6cebf89e5d733cb@o4511580502360064.ingest.us.sentry.io/4511762421907456"

    static var telemetryEnabled: Bool { !telemetryDeckAppID.isEmpty }
    static var sentryEnabled: Bool { !sentryDSN.isEmpty }
}
