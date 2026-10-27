import CryptoKit
import Foundation

/// Identifies the same meeting across two source calendars.
///
/// A join link is the strongest signal: both copies of a Teams, Zoom or Google Meet
/// invitation carry the same URL. Without one, the title and the start time are used.
/// The identity is hashed before it reaches a mapping, so the meeting URL is not stored
/// a second time on disk.
nonisolated struct MeetingIdentity: Hashable, Sendable {
    /// Stable key used as the mapping key for a merge job.
    var key: String
    /// True when a join link, rather than title and time, produced the key. Only strong
    /// identities may adopt a destination event that CalSync did not create itself.
    var isStrong: Bool

    static func of(_ payload: EventPayload) -> MeetingIdentity {
        let date = dateKey(for: payload)
        if let link = joinLink(in: payload) {
            return MeetingIdentity(key: "url:" + digest(link + "|" + date), isStrong: true)
        }
        let title = normalizedTitle(payload.title)
        return MeetingIdentity(key: "title:" + digest(title + "|" + date), isStrong: false)
    }

    // MARK: - Time

    private static func dateKey(for payload: EventPayload) -> String {
        if payload.isAllDay {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = payload.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
            let day = calendar.dateComponents([.year, .month, .day], from: payload.startDate)
            return String(
                format: "%04d-%02d-%02d",
                day.year ?? 0,
                day.month ?? 0,
                day.day ?? 0
            )
        }
        // Minute granularity absorbs a copy that was saved a few seconds off. It is still
        // far below the distance between two occurrences of the same recurring meeting.
        return String(Int((payload.startDate.timeIntervalSince1970 / 60).rounded(.down)))
    }

    // MARK: - Join links

    private static func joinLink(in payload: EventPayload) -> String? {
        // Prefer a known meeting host wherever it appears. Outlook often puts the Teams link
        // in the notes and an unrelated intranet link in the URL field; the join link is the
        // one both copies share.
        if let url = payload.url, isMeetingHost(url.host), let normalized = normalizedLink(url) {
            return normalized
        }
        for text in [payload.notes, payload.location].compactMap({ $0 }) {
            for candidate in links(in: text) where isMeetingHost(candidate.host) {
                if let normalized = normalizedLink(candidate) { return normalized }
            }
        }
        // A URL field that is not a known host is still an intentional identifier.
        if let url = payload.url, let normalized = normalizedLink(url) {
            return normalized
        }
        return nil
    }

    private static func links(in text: String) -> [URL] {
        let pattern = /(?i)\b(?:https?|msteams):\/\/[^\s<>"']+/
        return text.matches(of: pattern).compactMap { match in
            var raw = String(text[match.range])
            // A URL at the end of a sentence usually brings its punctuation along.
            while let last = raw.last, ".,;:!?)]}".contains(last) {
                raw.removeLast()
            }
            return URL(string: raw)
        }
    }

    private static let meetingHosts = [
        "teams.microsoft.com",
        "teams.live.com",
        "teams.cloud.microsoft",
        "zoom.us",
        "zoomgov.com",
        "meet.google.com",
        "meet.lync.com",
        "join.skype.com",
        "webex.com",
        "gotomeeting.com",
        "bluejeans.com",
        "whereby.com",
        "meet.jit.si",
        "chime.aws",
    ]

    private static func isMeetingHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func normalizedLink(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "msteams" else {
            return nil
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.fragment = nil

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path

        if let items = components.queryItems {
            let kept = items
                .filter { !$0.name.lowercased().hasPrefix("utm_") }
                .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        guard let string = components.string, !string.isEmpty else { return nil }
        return string
    }

    // MARK: - Fallback

    private static func normalizedTitle(_ title: String) -> String {
        let folded = title.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
