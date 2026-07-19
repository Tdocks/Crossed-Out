import Foundation

/// App Store Connect product identifiers for Crossed Out Plus.
/// Create matching auto-renewable subscriptions in ASC before shipping.
enum PlusProducts {
    static let monthlyID = "com.tdocks.crossedout.plus.monthly"
    static let annualID = "com.tdocks.crossedout.plus.annual"

    static let allIDs: Set<String> = [monthlyID, annualID]

    /// Free-tier Kyra messages / day (edge default).
    static let freeKyraDailyLimit = 30
    /// Plus-tier Kyra messages / day.
    static let plusKyraDailyLimit = 200
}
