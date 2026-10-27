import Foundation
import Testing
@testable import CalSync

struct MeetingIdentityTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22tenant%22%7d"

    private func payload(
        _ title: String,
        day: Double = 0,
        notes: String? = nil,
        location: String? = nil,
        url: URL? = nil,
        allDay: Bool = false,
        timeZone: String? = nil
    ) -> EventPayload {
        let start = base.addingTimeInterval(day * 86_400)
        return EventPayload(
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(allDay ? 0 : 3_600),
            isAllDay: allDay,
            timeZoneID: timeZone,
            location: location,
            notes: notes,
            url: url
        )
    }

    @Test func sameJoinLinkInNotesIsStrongAndIgnoresTitle() {
        let a = payload("Weekly", notes: "Join\n\(teams)")
        let b = payload("Weekly sync", notes: "Agenda\n\(teams)")
        let first = MeetingIdentity.of(a)
        let second = MeetingIdentity.of(b)
        #expect(first == second)
        #expect(first.isStrong)
    }

    @Test func sameURLInTheURLFieldIsStrong() {
        let a = payload("A", url: URL(string: "https://zoom.us/j/123456789"))
        let b = payload("B", url: URL(string: "https://zoom.us/j/123456789/"))
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
        #expect(MeetingIdentity.of(a).isStrong)
    }

    @Test func joinLinkInLocationIsFound() {
        let a = payload("Weekly", location: "Microsoft Teams Meeting\n\(teams)")
        let b = payload("Weekly sync", notes: teams)
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
        #expect(MeetingIdentity.of(a).isStrong)
    }

    @Test func aTeamsLinkInNotesBeatsAnUnrelatedURLField() {
        let a = payload(
            "Weekly",
            notes: teams,
            url: URL(string: "https://intranet.example.com/meetings")
        )
        let b = payload("Weekly sync", notes: teams)
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
    }

    @Test func differentJoinLinksAtTheSameTimeDiffer() {
        let a = payload("Standup", url: URL(string: "https://zoom.us/j/111"))
        let b = payload("Standup", url: URL(string: "https://zoom.us/j/222"))
        #expect(MeetingIdentity.of(a).key != MeetingIdentity.of(b).key)
    }

    @Test func sameJoinLinkAtDifferentTimesDiffer() {
        let a = payload("Standup", day: 0, url: URL(string: "https://zoom.us/j/111"))
        let b = payload("Standup", day: 1, url: URL(string: "https://zoom.us/j/111"))
        #expect(MeetingIdentity.of(a).key != MeetingIdentity.of(b).key)
    }

    @Test func aFewSecondsOfClockSkewDoNotSplitTheMeeting() {
        var a = payload("Weekly", url: URL(string: "https://zoom.us/j/111"))
        var b = a
        a.startDate = a.startDate.addingTimeInterval(30)
        b.startDate = b.startDate.addingTimeInterval(10)
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
    }

    @Test func fallbackNormalizesTitleAndIsWeak() {
        let a = payload("Weekly  Sync!")
        let b = payload("weekly sync")
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
        #expect(!MeetingIdentity.of(a).isStrong)
    }

    @Test func fallbackDifferentTitlesDiffer() {
        let a = payload("Standup")
        let b = payload("Retro")
        #expect(MeetingIdentity.of(a).key != MeetingIdentity.of(b).key)
    }

    @Test func ignoresUTMParameters() {
        let a = payload("A", url: URL(string: "https://zoom.us/j/123?utm_source=cal"))
        let b = payload("B", url: URL(string: "https://zoom.us/j/123"))
        #expect(MeetingIdentity.of(a) == MeetingIdentity.of(b))
    }

    @Test func unrelatedLinkInNotesIsNotAJoinLink() {
        let a = payload("Standup", notes: "Ticket https://jira.example.com/browse/ABC-1")
        #expect(!MeetingIdentity.of(a).isStrong)
    }

    @Test func emailURLIsNotAJoinLink() {
        let a = payload("Standup", url: URL(string: "mailto:standup@example.com"))
        #expect(!MeetingIdentity.of(a).isStrong)
    }

    @Test func allDayEventsUseTheirLocalDay() {
        let a = payload("Holiday", day: 0, allDay: true, timeZone: "Europe/Berlin")
        let b = payload("Holiday", day: 1, allDay: true, timeZone: "Europe/Berlin")
        #expect(MeetingIdentity.of(a).key != MeetingIdentity.of(b).key)
    }
}
