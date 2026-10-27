import Foundation
import Testing
@testable import CalSync

struct SyncJobSourcesTests {
    @Test func decodesAnOldSingleSourceJob() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "sourceCalendarID": "source",
          "sourceCalendarTitle": "Work",
          "sourceAccountTitle": "Exchange",
          "destinationCalendarID": "destination"
        }
        """
        let job = try JSONDecoder().decode(SyncJob.self, from: Data(json.utf8))
        #expect(job.sources.count == 1)
        #expect(job.sourceCalendarID == "source")
        #expect(job.sourceCalendarTitle == "Work")
        #expect(job.sourceAccountTitle == "Exchange")
        #expect(!job.isMerge)
    }

    @Test func roundTripsSeveralSources() throws {
        var job = SyncJob()
        job.sources = [
            SourceCalendar(calendarID: "mine", calendarTitle: "Me"),
            SourceCalendar(calendarID: "theirs", calendarTitle: "Wife"),
        ]
        job.destinationCalendarID = "shared"
        job.destinationCalendarTitle = "Our work"

        let decoded = try JSONDecoder().decode(SyncJob.self, from: JSONEncoder().encode(job))
        #expect(decoded == job)
        #expect(decoded.isMerge)
    }

    @Test func writesSourcesWithoutAPartialLegacyShape() throws {
        var job = SyncJob()
        job.sources = [
            SourceCalendar(calendarID: "mine"),
            SourceCalendar(calendarID: "theirs"),
        ]
        job.destinationCalendarID = "shared"

        let data = try JSONEncoder().encode(job)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((object["sources"] as? [[String: Any]])?.count == 2)
        // An older build must not see only the first source and then delete the copies that
        // belong to the other one. It sees a job without a source instead.
        #expect(object["sourceCalendarID"] == nil)
    }

    @Test func roundTripsSourceCounts() throws {
        var result = SyncResult()
        result.sourceCounts = ["mine": 12, "feed": 3]
        let decoded = try JSONDecoder().decode(SyncResult.self, from: JSONEncoder().encode(result))
        #expect(decoded.sourceCounts == ["mine": 12, "feed": 3])
    }

    @Test func validatesSourceSets() {
        var job = SyncJob()
        job.destinationCalendarID = "destination"
        #expect(!job.isValid)

        job.sources = [SourceCalendar(calendarID: "a"), SourceCalendar(calendarID: "a")]
        #expect(!job.isValid)

        job.sources = [SourceCalendar(calendarID: "a"), SourceCalendar(calendarID: "destination")]
        #expect(!job.isValid)

        job.sources = [SourceCalendar(calendarID: "a"), SourceCalendar(calendarID: "b")]
        #expect(job.isValid)
        #expect(job.isMerge)
    }
}
