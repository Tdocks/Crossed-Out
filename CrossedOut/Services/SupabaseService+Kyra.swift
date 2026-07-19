import Foundation
import Supabase

// MARK: - Kyra conversation history (migration 0024)

/// Persists the user's rolling Kyra conversation so it survives sessions and
/// devices. `kyra_messages` is own-rows RLS: select/insert/delete only —
/// messages are immutable once written, and "start fresh" is a delete of the
/// user's own rows.
extension SupabaseService {

    private struct KyraMessageRow: Decodable {
        let id: UUID
        let role: String
        let body: String

        enum CodingKeys: String, CodingKey {
            case id, role, body
        }
    }

    private struct KyraMessageInsert: Encodable {
        let id: UUID
        let user_id: UUID
        let role: String
        let body: String
    }

    /// Loads the most recent `limit` messages, oldest-first (display order).
    /// Throws on network failure so the view can distinguish "no history yet"
    /// from "couldn't load".
    func fetchKyraHistory(limit: Int = 60) async throws -> [ChatMessage] {
        guard let uid = currentUserID else { return [] }
        let rows: [KyraMessageRow] = try await client
            .from("kyra_messages")
            .select("id, role, body")
            .eq("user_id", value: uid)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.reversed().map { row in
            ChatMessage(id: row.id, role: ChatRole(rawValue: row.role) ?? .kyra, text: row.body)
        }
    }

    /// Fire-and-forget persistence of a single message. Reuses the message's
    /// client-side UUID as the row id, so an accidental double-save is a
    /// conflict no-op rather than a duplicate.
    func saveKyraMessage(_ message: ChatMessage) async {
        guard let uid = currentUserID else { return }
        let payload = KyraMessageInsert(
            id: message.id,
            user_id: uid,
            role: message.role.rawValue,
            body: String(message.text.prefix(6000))
        )
        do {
            try await client
                .from("kyra_messages")
                .upsert(payload, onConflict: "id", ignoreDuplicates: true)
                .execute()
        } catch {
            print("SupabaseService: saveKyraMessage failed: \(error)")
        }
    }

    /// "Start fresh": deletes the user's entire conversation. Returns false
    /// on failure so the view can leave the local transcript untouched.
    func clearKyraHistory() async -> Bool {
        guard let uid = currentUserID else { return false }
        do {
            try await client
                .from("kyra_messages")
                .delete()
                .eq("user_id", value: uid)
                .execute()
            return true
        } catch {
            print("SupabaseService: clearKyraHistory failed: \(error)")
            return false
        }
    }
}

// MARK: - Streaming ask (SSE)

/// Streaming variant of askKyra. The edge function performs all gating
/// (auth, anonymous check, daily cap → 429) and grounding retrieval BEFORE
/// the stream starts, so status handling here is identical to the JSON path
/// — the headers arrive first, then tokens. Falls back transparently to
/// parsing a plain JSON `{text}` body if the deployed function doesn't
/// stream yet (pre-redeploy compatibility).
extension SupabaseService {

    private struct KyraStreamRequestMessage: Encodable {
        let role: String
        let text: String
    }

    private struct KyraStreamRequestBody: Encodable {
        let messages: [KyraStreamRequestMessage]
        let firstName: String?
        let stream: Bool
    }

    private struct KyraStreamDelta: Decodable {
        let delta: String
    }

    private struct KyraStreamJSONFallback: Decodable {
        let text: String?
    }

    /// Calls the kyra edge function with `stream: true` and delivers tokens
    /// incrementally via `onDelta` (invoked on the main actor). Returns the
    /// complete reply text once the stream finishes.
    func askKyraStreaming(
        messages: [ChatMessage],
        firstName: String?,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard let session = client.auth.currentSession else {
            throw KyraServiceError.notSignedIn
        }

        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/kyra")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body = KyraStreamRequestBody(
            messages: messages.map { KyraStreamRequestMessage(role: $0.role.rawValue, text: $0.text) },
            firstName: firstName,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KyraServiceError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 { throw KyraServiceError.dailyLimitReached }
            throw KyraServiceError.badResponse
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""

        // Pre-redeploy compatibility: an older deployed function ignores the
        // stream flag and returns JSON. Collect the body and deliver it as
        // one "delta" so the UI path stays identical.
        if !contentType.contains("text/event-stream") {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            let decoded = try JSONDecoder().decode(KyraStreamJSONFallback.self, from: data)
            guard let text = decoded.text, !text.isEmpty else {
                throw KyraServiceError.missingText
            }
            await onDelta(text)
            return text
        }

        // SSE: `data: {"delta":"..."}` per token, terminated by `data: [DONE]`.
        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard
                let data = payload.data(using: .utf8),
                let chunk = try? JSONDecoder().decode(KyraStreamDelta.self, from: data)
            else { continue }
            full += chunk.delta
            await onDelta(chunk.delta)
        }

        guard !full.isEmpty else {
            throw KyraServiceError.missingText
        }
        return full
    }
}
