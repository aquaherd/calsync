import Foundation
import Testing
@testable import CalSync

struct SyncPlannerTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private var window: DateInterval { DateInterval(start: base, duration: 30 * 86_400) }

    private func payload(_ title: String, day: Double, hours: Double = 1) -> EventPayload {
        let start = base.addingTimeInterval(day * 86_400)
        return EventPayload(title: title, startDate: start, endDate: start.addingTimeInterval(hours * 3_600), isAllDay: false)
    }

    private func plan(
        source: [SourceOccurrence],
        mapping: [String: MappingEntry] = [:],
        existing: Set<String> = [],
        claimed: Set<String> = [],
        destination: [DestinationEvent] = [],
        deleteRemoved: Bool = true
    ) -> SyncPlan {
        SyncPlanner.plan(source: source, mapping: mapping, existingDestinationIDs: existing,
                         claimedDestinationIDs: claimed, destinationEvents: destination,
                         window: window, deleteRemoved: deleteRemoved)
    }

    @Test func createsNewEvents() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(source: [a])
        #expect(result.actions == [.create(a)])
        #expect(result.unchanged == 0)
    }

    @Test func skipsUnchangedEvents() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(source: [a], mapping: ["a": .init(destinationID: "d1", payload: a.payload)], existing: ["d1"])
        #expect(result.actions.isEmpty)
        #expect(result.unchanged == 1)
    }

    @Test func updatesChangedEvents() {
        let old = payload("Standup", day: 1)
        let a = SourceOccurrence(key: "a", payload: payload("Standup (moved)", day: 2))
        let result = plan(source: [a], mapping: ["a": .init(destinationID: "d1", payload: old)], existing: ["d1"])
        #expect(result.actions == [.update(destinationID: "d1", a)])
    }

    @Test func recreatesWhenCopyWasDeleted() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(source: [a], mapping: ["a": .init(destinationID: "gone", payload: a.payload)], existing: [])
        #expect(result.actions == [.create(a)])
    }

    @Test func adoptsIdenticalUnmappedDestinationEvent() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(source: [a], destination: [DestinationEvent(id: "d9", payload: a.payload)])
        #expect(result.actions == [.update(destinationID: "d9", a)])
    }

    @Test func doesNotAdoptEventClaimedByAnotherMapping() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let b = SourceOccurrence(key: "b", payload: a.payload)
        let result = plan(
            source: [a, b],
            mapping: ["a": .init(destinationID: "d1", payload: a.payload)],
            existing: ["d1"],
            destination: [DestinationEvent(id: "d1", payload: a.payload)]
        )
        #expect(result.unchanged == 1)
        #expect(result.actions == [.create(b)])
    }

    @Test func deletesCopiesOfRemovedEvents() {
        let gone = payload("Cancelled", day: 3)
        let result = plan(source: [], mapping: ["x": .init(destinationID: "d1", payload: gone)], existing: ["d1"])
        #expect(result.actions == [.delete(destinationID: "d1", key: "x")])
    }

    @Test func forgetsRemovedEventsWhenDeletionDisabled() {
        let gone = payload("Cancelled", day: 3)
        let result = plan(source: [], mapping: ["x": .init(destinationID: "d1", payload: gone)], existing: ["d1"], deleteRemoved: false)
        #expect(result.actions.isEmpty)
        #expect(result.forget == ["x"])
    }

    @Test func keepsCopiesThatScrolledIntoThePast() {
        let past = payload("Old meeting", day: -5)
        let result = plan(source: [], mapping: ["p": .init(destinationID: "d1", payload: past)], existing: ["d1"])
        #expect(result.actions.isEmpty)
        #expect(result.forget == ["p"])
    }

    @Test func leavesMappingsBeyondWindowAlone() {
        let future = payload("Far future", day: 90)
        let result = plan(source: [], mapping: ["f": .init(destinationID: "d1", payload: future)], existing: ["d1"])
        #expect(result.actions.isEmpty)
        #expect(result.forget.isEmpty)
    }

    @Test func ignoresDuplicateSourceKeys() {
        let a = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(source: [a, a])
        #expect(result.actions == [.create(a)])
    }

    @Test func windowCoversPastAndFutureDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let job = SyncJob(daysBack: 7, daysAhead: 30)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let window = job.window(now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        #expect(window.start == today.addingTimeInterval(-7 * 86_400))
        #expect(window.end == today.addingTimeInterval(31 * 86_400))
    }

    // MARK: - Adoption safety

    @Test func doesNotAdoptLookAlikeWithDifferentDetails() {
        let sourcePayload = payload("Standup", day: 1)
        var lookAlike = sourcePayload
        lookAlike.notes = "My own note"
        lookAlike.location = "My office"
        let occurrence = SourceOccurrence(key: "a", payload: sourcePayload)
        let result = plan(
            source: [occurrence],
            destination: [DestinationEvent(id: "personal", payload: lookAlike)]
        )
        #expect(result.actions == [.create(occurrence)])
    }

    @Test func doesNotAdoptCopyClaimedByAnotherJob() {
        let occurrence = SourceOccurrence(key: "a", payload: payload("Standup", day: 1))
        let result = plan(
            source: [occurrence],
            claimed: ["other-job-copy"],
            destination: [DestinationEvent(id: "other-job-copy", payload: occurrence.payload)]
        )
        #expect(result.actions == [.create(occurrence)])
    }

    // MARK: - Mass deletion guard

    @Test func blocksDeletionWhenSourceLooksEmpty() {
        let gone = payload("Cancelled", day: 3)
        let plan = plan(
            source: [],
            mapping: ["x": .init(destinationID: "d1", payload: gone)],
            existing: ["d1"]
        )
        #expect(SyncPlanner.blockedDeletionCount(in: plan, sourceCount: 0) == 1)
    }

    @Test func allowsSmallCleanupWhileSourceStillHasEvents() {
        let actions = (0..<3).map { index in
            SyncAction.delete(destinationID: "d\(index)", key: "k\(index)")
        }
        let plan = SyncPlan(actions: actions)
        #expect(SyncPlanner.blockedDeletionCount(in: plan, sourceCount: 20) == nil)
    }

    @Test func blocksRemovalOfMoreThanHalfTheTrackedEvents() {
        let actions = (0..<12).map { index in
            SyncAction.delete(destinationID: "d\(index)", key: "k\(index)")
        }
        let plan = SyncPlan(actions: actions)
        #expect(SyncPlanner.blockedDeletionCount(in: plan, sourceCount: 10) == 12)
    }

    @Test func blocksAlmostEmptyingASmallCalendar() {
        let actions = (0..<9).map { index in
            SyncAction.delete(destinationID: "d\(index)", key: "k\(index)")
        }
        let plan = SyncPlan(actions: actions)
        #expect(SyncPlanner.blockedDeletionCount(in: plan, sourceCount: 1) == 9)
    }

    @Test func allowsLargeCleanupInALargeCalendar() {
        let actions = (0..<12).map { index in
            SyncAction.delete(destinationID: "d\(index)", key: "k\(index)")
        }
        let plan = SyncPlan(actions: actions)
        #expect(SyncPlanner.blockedDeletionCount(in: plan, sourceCount: 100) == nil)
    }

    @Test func allowsEmptyPlanWithoutDeletions() {
        #expect(SyncPlanner.blockedDeletionCount(in: SyncPlan(), sourceCount: 0) == nil)
    }
}
