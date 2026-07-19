import Foundation
import OSLog
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif
#if canImport(Sentry)
import Sentry
#endif

/// Privacy-first analytics + crash hook seam.
/// - Always logs locally via OSLog.
/// - Uploads only when `AppSecrets` keys are filled: TelemetryDeck for signals,
///   Sentry for crashes/errors. Both SDKs are `#if canImport`-guarded so the
///   app still builds if a package isn't resolved.
/// Privacy rule: only event NAMES + coarse enums ever leave the device — never
/// verse text, prayers, Kyra message bodies, reflections, or names.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let log = Logger(subsystem: "com.tdocks.crossedout", category: "analytics")

    private init() {}

    func start() {
        log.info("Analytics start — telemetry=\(AppSecrets.telemetryEnabled) sentry=\(AppSecrets.sentryEnabled)")

        #if canImport(TelemetryDeck)
        if AppSecrets.telemetryEnabled {
            TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: AppSecrets.telemetryDeckAppID))
        }
        #endif

        #if canImport(Sentry)
        if AppSecrets.sentryEnabled {
            SentrySDK.start { options in
                options.dsn = AppSecrets.sentryDSN
                options.enableAutoSessionTracking = true
                options.tracesSampleRate = 0.0          // errors/crashes only; no perf sampling
                options.attachStacktrace = true
                #if DEBUG
                options.environment = "debug"
                #else
                options.environment = "production"
                #endif
            }
        }
        #endif

        track("app_launch")
    }

    func track(_ name: String, _ params: [String: String] = [:]) {
        if params.isEmpty {
            log.info("event \(name, privacy: .public)")
        } else {
            let joined = params.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
            log.info("event \(name, privacy: .public) \(joined, privacy: .public)")
        }
        #if canImport(TelemetryDeck)
        if AppSecrets.telemetryEnabled {
            TelemetryDeck.signal(name, parameters: params)
        }
        #endif
        // Never forward verse text, prayers, Kyra bodies, reflections, or names —
        // signal names + coarse enums only.
    }

    func breadcrumb(_ message: String) {
        log.debug("\(message, privacy: .public)")
        #if canImport(Sentry)
        if AppSecrets.sentryEnabled {
            let crumb = Breadcrumb(level: .info, category: "app")
            crumb.message = message
            SentrySDK.addBreadcrumb(crumb)
        }
        #endif
    }

    func captureError(_ error: Error, context: String) {
        log.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        #if canImport(Sentry)
        if AppSecrets.sentryEnabled {
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: ["where": context], key: "app")
            }
        }
        #endif
    }
}
