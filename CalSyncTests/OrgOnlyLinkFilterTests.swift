import Foundation
import Testing
@testable import CalSync

struct OrgOnlyLinkFilterTests {
    private let teamsLink = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22tenant%22%7d"

    @Test func removesTeamsLinkAndJoinBoilerplate() {
        let notes = """
        Join the meeting now
        \(teamsLink)

        Meeting ID: 123 456 789
        Passcode: 7abc
        """
        let filtered = OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes)
        #expect(filtered?.contains("teams.microsoft.com") == false)
        #expect(filtered?.contains("Join the meeting now") == false)
        #expect(filtered?.contains("Meeting ID: 123 456 789") == true)
    }

    @Test func removesOutlookJoinBlock() {
        let notes = """
        Microsoft Teams meeting
        Join on your computer, mobile app or room device
        Click here to join the meeting
        \(teamsLink)

        Meeting ID: 123 456 789
        Passcode: 7abc
        Download Teams | Join on the web
        """
        let filtered = OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes)
        #expect(filtered?.contains("Microsoft Teams") == false)
        #expect(filtered?.contains("Download Teams") == false)
        #expect(filtered?.contains("Click here") == false)
        #expect(filtered?.contains("Meeting ID: 123 456 789") == true)
        #expect(filtered?.contains("Passcode: 7abc") == true)
    }

    @Test func removesConsumerAndDeepLinks() {
        let notes = """
        Join: https://teams.live.com/meet/123456789
        Phone: msteams://teams.microsoft.com/l/meetup-join/abc
        """
        let filtered = OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes)
        #expect(filtered == nil)
    }

    @Test func removesHTMLLink() {
        let notes = #"<a href="https://teams.microsoft.com/l/meetup-join/abc">Join now</a>"#
        #expect(OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes) == nil)
    }

    @Test func removesMarkdownLink() {
        let notes = "[Join now](https://teams.cloud.microsoft/meet/abc)"
        #expect(OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes) == nil)
    }

    @Test func keepsOtherMeetingLinks() {
        let notes = """
        Join: https://zoom.us/j/123456789
        Notes: https://meet.google.com/abc-defg-hij
        """
        #expect(OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes) == notes)
    }

    @Test func keepsPlainTextThatMentionsTeams() {
        let notes = "Microsoft Teams is down today, use the phone bridge."
        #expect(OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes) == notes)
    }

    @Test func keepsSurroundingAgendaText() {
        let notes = """
        Agenda
        - Roadmap
        Join: \(teamsLink)
        Owner: Hakan
        """
        let filtered = OrgOnlyLinkFilter.removingOrgOnlyLinks(from: notes)
        #expect(filtered?.contains("Agenda") == true)
        #expect(filtered?.contains("Roadmap") == true)
        #expect(filtered?.contains("Owner: Hakan") == true)
        #expect(filtered?.contains("teams") == false)
    }

    @Test func stripsLocationWithLink() {
        let payload = EventPayload(
            title: "Sync",
            startDate: .now,
            endDate: .now.addingTimeInterval(3_600),
            isAllDay: false,
            location: "Microsoft Teams Meeting\n\(teamsLink)"
        )
        let stripped = OrgOnlyLinkFilter.strip(from: payload, copyURL: false)
        #expect(stripped.location == nil)
    }

    @Test func leavesPayloadAloneWhenURLCopyingIsOn() {
        let payload = EventPayload(
            title: "Sync",
            startDate: .now,
            endDate: .now.addingTimeInterval(3_600),
            isAllDay: false,
            location: teamsLink,
            notes: teamsLink
        )
        #expect(OrgOnlyLinkFilter.strip(from: payload, copyURL: true) == payload)
    }

    @Test func fingerprintChangesWithContent() {
        var payload = EventPayload(
            title: "Sync",
            startDate: .now,
            endDate: .now.addingTimeInterval(3_600),
            isAllDay: false
        )
        let before = payload.fingerprint
        payload.notes = "Changed"
        #expect(before != payload.fingerprint)
    }
}

struct PersistenceTests {
    @Test func decodesJobWithoutNewerFields() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "sourceCalendarID": "source",
          "destinationCalendarID": "destination",
          "daysBack": 3,
          "daysAhead": 14
        }
        """
        let job = try JSONDecoder().decode(SyncJob.self, from: Data(json.utf8))
        #expect(job.daysBack == 3)
        #expect(job.daysAhead == 14)
        #expect(job.options.copyNotes)
        #expect(job.isEnabled)
        #expect(job.sourceCalendarTitle == nil)
    }

    @Test func roundTripsJobWithCalendarMetadata() throws {
        var job = SyncJob()
        job.sourceCalendarID = "source"
        job.destinationCalendarID = "destination"
        job.sourceCalendarTitle = "Hakan"
        job.sourceAccountTitle = "iCloud"
        job.destinationCalendarTitle = "Family"
        job.destinationAccountTitle = "iCloud"

        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(SyncJob.self, from: data)
        #expect(decoded == job)
    }

    @Test func decodesLegacyMappingPayload() throws {
        let payload = EventPayload(
            title: "Standup",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_003_600),
            isAllDay: false,
            notes: "Sensitive work notes",
            url: URL(string: "https://example.com")
        )
        let legacy = try JSONEncoder().encode(["key": LegacyMapping(destinationID: "d1", payload: payload)])
        let decoded = try JSONDecoder().decode([String: MappingEntry].self, from: legacy)
        let entry = try #require(decoded["key"])
        #expect(entry.destinationID == "d1")
        #expect(entry.fingerprint == payload.fingerprint)
        #expect(entry.needsMigration)

        let rewritten = try JSONEncoder().encode(["key": entry])
        let text = String(decoding: rewritten, as: UTF8.self)
        #expect(!text.contains("Sensitive work notes"))
        let migrated = try JSONDecoder().decode([String: MappingEntry].self, from: rewritten)
        #expect(migrated["key"]?.needsMigration == false)
    }
}

private struct LegacyMapping: Codable {
    var destinationID: String
    var payload: EventPayload
}
