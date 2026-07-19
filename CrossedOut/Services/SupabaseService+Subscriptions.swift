import Foundation
import Supabase

extension SupabaseService {
    /// Reads whether the server currently considers this user Plus.
    func fetchIsPlus() async -> Bool {
        guard currentUserID != nil else { return false }
        do {
            let response = try await client.rpc("is_plus").execute()
            if let flag = try? JSONDecoder().decode(Bool.self, from: response.data) {
                return flag
            }
            if let str = String(data: response.data, encoding: .utf8) {
                return str.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            }
        } catch {
            print("SupabaseService: fetchIsPlus failed: \(error)")
        }
        return false
    }
}
