import Foundation
import Testing
@testable import CalSync

struct MergePlannerTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22tenant%22%7d"
    private var window: DateInterval { DateInterval(start: base, duration: 30 * 86_400) }

    private func payload(
        _ title: String,
        day: Double,
        url: String? = nil,
        notes: String? = nil
    ) -> EventPayload {
        let start = base.addingTimeInterval(day * 86_400)
        return EventPayload(
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            notes: notes,
            url: url.flatMap(URL.init(string:))
        )
    }

    private func occurrence(
        _ title: String,
        day: Double,
        url: String? = nil,
        notes: String? = nil
    ) -> SourceOccurrence {
        let payload = payload(title, day: day, url: url, notes: notes)
        let identity = MeetingIdentity.of(payload)
        return SourceOccurrence(
            key: identity.key,
            payload: payload,
            hasStrongIdentity: identity.isStrong
        )
    }

    private func plan(
        source: [SourceOccurrence],
        mapping: [String: MappingEntry] = [:],
        existing: Set<String> = [],
        claimed: Set<String> = [],
        destination: [DestinationEvent] = [],
        deleteRemoved: Bool = true
    ) -> SyncPlan {
        SyncPlanner.plan(
            source: source,
            mapping: mapping,
            existingDestinationIDs: existing,
            claimedDestinationIDs: claimed,
            destinationEvents: destination,
            window: window,
            deleteRemoved: deleteRemoved,
            mergeDuplicates: true
        )
    }

    @Test func copiesAMeetingThatBothSourcesHaveOnlyOnce() {
        let mine = occurrence("Weekly", day: 1, url: teams)
        let theirs = occurrence("Weekly sync", day: 1, url: teams)
        let result = plan(source: [mine, theirs])
        #expect(result.actions == [.create(mine)])
    }

    @Test func keepsMeetingsThatOnlyOneSourceHas() {
        let mine = occurrence("Mine", day: 1, url: "https://zoom.us/j/111")
        let theirs = occurrence("Theirs", day: 2, url: "https://zoom.us/j/222")
        let result = plan(source: [mine, theirs])
        #expect(result.actions == [.create(mine), .create(theirs)])
    }

    @Test func usesTheFirstSourceAsTheCanonicalCopy() {
        let mine = occurrence("Mine", day: 1, url: teams)
        let theirs = occurrence("Theirs", day: 1, url: teams)
        let result = plan(source: [mine, theirs])
        #expect(result.actions == [.create(mine)])
    }

    @Test func updatesWhenTheCanonicalPayloadChanges() {
        let old = occurrence("Old", day: 1, url: teams)
        let new = occurrence("New", day: 1, url: teams)
        let mapping = [old.key: MappingEntry(destinationID: "d1", payload: old.payload)]
        let result = plan(source: [new], mapping: mapping, existing: ["d1"])
        #expect(result.actions == [.update(destinationID: "d1", new)])
    }

    @Test func keepsTheCopyWhenOnlyOneSourceLosesTheMeeting() {
        let mine = occurrence("Mine", day: 1, url: teams)
        let theirs = occurrence("Theirs", day: 1, url: teams)
        let mapping = [mine.key: MappingEntry(destinationID: "d1", payload: mine.payload)]
        let result = plan(
            source: [theirs],
            mapping: mapping,
            existing: ["d1"],
            destination: [DestinationEvent(id: "d1", payload: mine.payload)]
        )
        #expect(result.actions == [.update(destinationID: "d1", theirs)])
        #expect(result.deletionCount == 0)
    }

    @Test func deletesOnlyWhenBothSourcesLoseTheMeeting() {
        let gone = occurrence("Gone", day: 1, url: teams)
        let mapping = [gone.key: MappingEntry(destinationID: "d1", payload: gone.payload)]
        let result = plan(source: [], mapping: mapping, existing: ["d1"])
        #expect(result.actions == [.delete(destinationID: "d1", key: gone.key)])
    }

    @Test func blocksDeletionWhenOneSourceIsEmpty() {
        let gone = occurrence("Gone", day: 1, url: teams)
        let other = occurrence("Other", day: 2, url: "https://zoom.us/j/999")
        let mapping = [gone.key: MappingEntry(destinationID: "d1", payload: gone.payload)]
        let result = plan(source: [other], mapping: mapping, existing: ["d1"])
        #expect(result.deletionCount == 1)
        #expect(
            SyncPlanner.blockedDeletionCount(
                in: result,
                sourceCount: 1,
                hasEmptySource: true
            ) == 1
        )
    }

    @Test func adoptsADestinationCopyByJoinLink() {
        let mine = occurrence("Weekly sync", day: 1, url: teams, notes: "Agenda")
        let theirCopy = DestinationEvent(id: "d9", payload: payload("Weekly", day: 1, url: teams))
        let result = plan(source: [mine], destination: [theirCopy])
        #expect(result.actions == [.update(destinationID: "d9", mine)])
    }

    @Test func adoptsAnIdenticalCopyWithoutAJoinLink() {
        let mine = occurrence("Standup", day: 1)
        let copy = DestinationEvent(id: "d9", payload: mine.payload)
        let result = plan(source: [mine], destination: [copy])
        #expect(result.actions == [.update(destinationID: "d9", mine)])
    }

    @Test func doesNotAdoptALookAlikeWithoutAJoinLink() {
        let mine = occurrence("Standup", day: 1)
        let lookAlike = DestinationEvent(
            id: "personal",
            payload: payload("Standup", day: 1, notes: "My own note")
        )
        let result = plan(source: [mine], destination: [lookAlike])
        #expect(result.actions == [.create(mine)])
    }

    @Test func aRescheduleReplacesTheOldCopy() {
        let old = occurrence("Weekly", day: 1, url: teams)
        let moved = occurrence("Weekly", day: 2, url: teams)
        let mapping = [old.key: MappingEntry(destinationID: "d1", payload: old.payload)]
        let result = plan(source: [moved], mapping: mapping, existing: ["d1"])
        #expect(result.actions.contains(.create(moved)))
        #expect(result.actions.contains(.delete(destinationID: "d1", key: old.key)))
    }

    @Test func rekeysAnOldMappingWithoutDeletingTheAdoptedCopy() {
        let meeting = occurrence("Weekly", day: 1, url: teams)
        let oldKey = "old-source-key|123"
        let mapping = [oldKey: MappingEntry(destinationID: "d1", payload: meeting.payload)]
        let result = plan(
            source: [meeting],
            mapping: mapping,
            existing: ["d1"],
            destination: [DestinationEvent(id: "d1", payload: meeting.payload)]
        )
        #expect(result.actions == [.update(destinationID: "d1", meeting)])
        #expect(result.forget == [oldKey])
        #expect(result.deletionCount == 0)
    }

    @Test func usesTitleAndTimeWhenThereIsNoJoinLink() {
        let mine = occurrence("Weekly  Sync!", day: 1)
        let theirs = occurrence("weekly sync", day: 1)
        let result = plan(source: [mine, theirs])
        #expect(result.actions == [.create(mine)])
    }

    @Test func differentMeetingsWithoutLinksAreBothCopied() {
        let standup = occurrence("Standup", day: 1)
        let retro = occurrence("Retro", day: 1)
        let result = plan(source: [standup, retro])
        #expect(result.actions == [.create(standup), .create(retro)])
    }

    @Test func anEmptySourceThatHadEventsIsSuspicious() {
        #expect(
            SyncPlanner.hasSuspiciousEmptySource(
                current: ["mine": 10, "feed": 0],
                previous: ["mine": 10, "feed": 4]
            )
        )
    }

    @Test func anEmptySourceThatWasAlwaysEmptyIsNotSuspicious() {
        #expect(
            !SyncPlanner.hasSuspiciousEmptySource(
                current: ["mine": 10, "feed": 0],
                previous: ["mine": 10, "feed": 0]
            )
        )
    }

    @Test func aSourceThatStillHasEventsIsNotSuspicious() {
        #expect(
            !SyncPlanner.hasSuspiciousEmptySource(
                current: ["mine": 8, "feed": 2],
                previous: ["mine": 10, "feed": 4]
            )
        )
    }

    @Test func aRemovedSourceIsNotSuspicious() {
        #expect(
            !SyncPlanner.hasSuspiciousEmptySource(
                current: ["mine": 10],
                previous: ["mine": 10, "feed": 4]
            )
        )
    }
}
