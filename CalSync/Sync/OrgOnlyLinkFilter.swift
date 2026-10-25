import Foundation

/// Removes links that only work inside a Microsoft 365 organization, such as Teams meeting
/// join links, from the free-text fields CalSync copies.
///
/// This runs only when the job does not copy the event URL, because in that case the user has
/// asked not to carry links over. Notes that contain no such link are returned unchanged.
nonisolated enum OrgOnlyLinkFilter {
    private static let orgOnlyHosts = [
        "teams.microsoft.com",
        "teams.live.com",
        "teams.cloud.microsoft",
        "teams.microsoft.us",
        "teams.gov.microsoft.us",
    ]

    static func strip(from payload: EventPayload, copyURL: Bool) -> EventPayload {
        guard !copyURL else { return payload }
        var payload = payload
        payload.notes = payload.notes.flatMap(removingOrgOnlyLinks(from:))
        payload.location = payload.location.flatMap(removingOrgOnlyLinks(from:))
        return payload
    }

    /// Returns `nil` when nothing but links and join boilerplate is left.
    static func removingOrgOnlyLinks(from text: String) -> String? {
        guard containsOrgOnlyLink(text) else { return text }

        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var lines: [String] = []
        var removedAny = false

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine)
            let before = line
            line = removingAnchors(from: line)
            line = removingMarkdownLinks(from: line)
            line = removingBareLinks(from: line)
            let changed = line != before
            removedAny = removedAny || changed

            guard changed else {
                lines.append(rawLine.isEmpty ? "" : String(rawLine))
                continue
            }

            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "<>[](){}"))
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "-–—:|·•,;"))
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isDanglingLabel(line) { line = "" }
            lines.append(line)
        }

        guard removedAny else { return text }

        let cleaned = lines
            .filter { line in
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return !isJoinBoilerplate(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }

    static func containsOrgOnlyLink(_ text: String) -> Bool {
        if containsAnchorLink(text) { return true }
        if containsMarkdownLink(text) { return true }
        return bareLinkRanges(in: text).contains { range in
            let raw = (text as NSString).substring(with: range)
            return isOrgOnlyLink(trimmedLink(raw))
        }
    }

    static func isOrgOnlyLink(_ raw: String) -> Bool {
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.lowercased().hasPrefix("msteams:") { return true }
        guard let url = URL(string: candidate), let host = url.host?.lowercased() else { return false }
        let cleanHost = host.split(separator: ":").first.map(String.init) ?? host
        if orgOnlyHosts.contains(where: { cleanHost == $0 || cleanHost.hasSuffix("." + $0) }) {
            return true
        }
        if cleanHost == "aka.ms" {
            // Short links such as https://aka.ms/JoinTeamsMeeting redirect to Teams.
            let path = url.path.lowercased()
            return path.contains("jointeams") || path.contains("teamsmeeting") || path.contains("meetnow")
        }
        return false
    }

    // MARK: - Link recognition and removal

    private static func containsAnchorLink(_ text: String) -> Bool {
        matches(anchorPattern, in: text).contains { match in
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return false }
            return isOrgOnlyLink((text as NSString).substring(with: range))
        }
    }

    private static func containsMarkdownLink(_ text: String) -> Bool {
        matches(markdownPattern, in: text).contains { match in
            let range = match.range(at: 2)
            guard range.location != NSNotFound else { return false }
            return isOrgOnlyLink((text as NSString).substring(with: range))
        }
    }

    private static func removingAnchors(from text: String) -> String {
        replacingMatches(anchorPattern, in: text) { match, source in
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return false }
            return isOrgOnlyLink((source as NSString).substring(with: range))
        }
    }

    private static func removingMarkdownLinks(from text: String) -> String {
        replacingMatches(markdownPattern, in: text) { match, source in
            let range = match.range(at: 2)
            guard range.location != NSNotFound else { return false }
            return isOrgOnlyLink((source as NSString).substring(with: range))
        }
    }

    private static func removingBareLinks(from text: String) -> String {
        let ranges = bareLinkRanges(in: text).filter { range in
            isOrgOnlyLink(trimmedLink((text as NSString).substring(with: range)))
        }
        guard !ranges.isEmpty else { return text }
        let mutable = NSMutableString(string: text)
        for range in ranges.reversed() {
            mutable.replaceCharacters(in: range, with: "")
        }
        return mutable as String
    }

    private static func bareLinkRanges(in text: String) -> [NSRange] {
        matches(linkPattern, in: text).map(\.range)
    }

    private static func trimmedLink(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'.,;:!?)]}"))
    }

    private static func replacingMatches(
        _ pattern: NSRegularExpression,
        in text: String,
        when shouldRemove: (NSTextCheckingResult, String) -> Bool
    ) -> String {
        let found = matches(pattern, in: text)
        guard !found.isEmpty else { return text }
        let mutable = NSMutableString(string: text)
        for match in found.reversed() where shouldRemove(match, text) {
            mutable.replaceCharacters(in: match.range, with: "")
        }
        return mutable as String
    }

    // MARK: - Boilerplate

    private static func isDanglingLabel(_ line: String) -> Bool {
        let normalized = line
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-–—:|·•,;"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let labels: Set<String> = [
            "join",
            "phone",
            "teams",
            "teams link",
            "meeting link",
            "link",
            "url",
            "meeting",
            "besprechung",
            "teilnehmen",
        ]
        return labels.contains(normalized)
    }

    private static func isJoinBoilerplate(_ line: String) -> Bool {
        let normalized = line
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-–—:|·•,;"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let exact: Set<String> = [
            "join the meeting",
            "join the meeting now",
            "join on your computer or mobile app",
            "join on your computer, mobile app or room device",
            "click here to join the meeting",
            "click here to join",
            "join with a video conferencing device",
            "join on the web",
            "download teams",
            "download teams | join on the web",
            "microsoft teams meeting",
            "microsoft teams",
            "an der besprechung teilnehmen",
            "jetzt an der besprechung teilnehmen",
            "per computer oder mobile app teilnehmen",
            "über computer oder mobile app teilnehmen",
            "per computer, mobile app oder raumgerät teilnehmen",
            "über computer, mobile app oder raumgerät teilnehmen",
            "hier klicken, um an der besprechung teilzunehmen",
            "microsoft teams-besprechung",
            "besprechung beitreten",
            "im web teilnehmen",
            "teams herunterladen",
            "teams herunterladen | im web teilnehmen",
        ]
        return exact.contains(normalized)
    }

    // MARK: - Regex

    private static var linkPattern: NSRegularExpression {
        // Deliberately stops at whitespace and markup so markdown and angle-bracket links
        // leave their delimiters behind for the caller to trim.
        try! NSRegularExpression(pattern: #"(?i)(?:https?://|msteams:)[^\s<>"']+"#)
    }

    private static var anchorPattern: NSRegularExpression {
        try! NSRegularExpression(pattern: #"(?is)<a\b[^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*>.*?</a>"#)
    }

    private static var markdownPattern: NSRegularExpression {
        try! NSRegularExpression(pattern: #"(?is)\[([^\]]*)\]\(((?:https?://|msteams:)[^)\s]+)\)"#)
    }

    private static func matches(_ pattern: NSRegularExpression, in text: String) -> [NSTextCheckingResult] {
        pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
