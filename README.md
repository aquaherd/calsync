# CalSync

CalSync is a small app for iPhone and iPad that copies events from one calendar to another, for example from a work Outlook/Exchange calendar to a personal iCloud calendar. It's built with SwiftUI and EventKit and targets iOS 26 and later.

## Features

- **Multiple syncs.** Each one copies one or more calendars to a writable destination calendar.
- **At home on iPad.** On iPad a two-column layout shows the syncs on the left and the editor for the selected sync on the right. It works in any window size, including Split View and Slide Over, and a hardware keyboard can use ⌘N for a new sync and ⌘R to sync all.
- **Merge calendars.** A sync can have several source calendars. A meeting that appears in more than one source is copied once. A join link (Teams, Zoom, Google Meet) identifies the same meeting even when the two copies have different titles; without one, the normalized title and start time are used.
- **Create the destination.** In the sync editor, **New Calendar…** creates an event calendar in iCloud or On My iPhone. Sharing it with someone else remains a one-time step in Calendar.
- **Updates stay in step.** Re-running a sync updates changed events and removes copies of deleted events. Each occurrence of a recurring event is copied as its own event.
- **No duplicates, no hijacking.** CalSync records which source event each copy came from. If those records are lost (for example after a reinstall), it re-links only events that match in every copied field, and never takes over a copy that belongs to another sync.
- **Large removals wait for you.** If a source account is offline or returns no events, the run stops before deleting the mirror. A foreground confirmation is required, so an unattended background run cannot wipe the destination.
- **Calendar changes are handled.** Re-pointing a sync offers to remove the old copies; calendars from an account that was removed and added again are reconnected by title.
- **Private mode.** Copies only the time slot, with a custom title such as "Busy".
- **Options.** Choose whether to copy location, notes, URL and alerts. You can skip declined, canceled or all-day events.
- **Teams links stay behind.** When "Copy URL" is off, Microsoft Teams join links and their join boilerplate are also removed from notes and location, because they only work inside the organization.
- **Readable errors.** The editor shows what the last run did and lists individual failures instead of only a count.
- **When it runs.** Syncs run when the app opens, on pull-to-refresh, and every so often in the background (`BGAppRefreshTask`).
- **Undo.** "Remove Copied Events" deletes every event a sync has created.

Mappings on disk contain only the destination identifier, the copied time range and a fingerprint of the copied fields. Notes, locations and URLs are not stored a second time; a merge job's meeting key is a hash.

## Safety behavior

- A run that would remove more than half of the tracked events, or any events while the source returns none, stops before changing anything and asks for confirmation. Background runs only record the error; the question appears the next time the app is open.
- Re-linking after a reinstall requires an exact match in every copied field and ignores copies that belong to another sync. A look-alike personal event is never taken over. A merge job can additionally adopt a copy by its join link.
- Changing a sync's sources or destination asks whether to remove the copies in the old calendar. If you keep them, CalSync no longer manages them.
- A merge job remembers how many events each source had. If a source that used to have events returns none, removals stop and ask, so an offline account cannot silently delete that person's unique meetings.
- If an account is removed and added again, its calendars get new identifiers. CalSync reconnects a sync by title and account when that match is unambiguous.

### Getting Outlook calendars onto the iPhone

CalSync works through iOS's calendar database (EventKit), so the Outlook calendar has to appear in Apple's Calendar app. To set that up, either:

- add the account under **Settings › Apps › Calendar › Calendar Accounts › Add Account › Microsoft Exchange / Outlook.com**, or
- in the Outlook iOS app, go to **Settings › your account › Sync Calendars** and turn it on.

## Shared calendars for two people

Two people in the same team can combine their work calendars into one shared iCloud calendar
without seeing every meeting twice:

```
her phone:  her work ──► "Her work" (shared iCloud feed) ─┐
                                                           ├─► "Our work" (shared, one writer)
your phone: your work ─────────────────────────────────────┘
```

- Create the calendars with **New Calendar…** in the sync editor, or in Calendar itself, and
  put them in iCloud. Then share them with edit permission in **Calendar › Calendars › Info**.
  EventKit can create and write a calendar but has no API to add participants, so the sharing
  step has to happen in Calendar. A dedicated calendar is better than the family calendar.
- Her phone runs an ordinary sync from her work calendar into the feed. Keep the meeting
  details, at least the join link: a private-mode feed carries only "Busy" blocks and cannot
  be matched reliably against your copies.
- Your phone runs a merge job with your work calendar and the feed as sources, into "Our work".
  It writes the result once, so the existing mapping and removal rules still apply.
- Only one phone writes the merged calendar. If both phones wrote it, each would need to know
  which copies the other owns; that is a much larger CloudKit-style problem.
- Show only "Our work" in Calendar to get the deduplicated view; the feed and the two work
  calendars still contain their own events.

This has two-hop freshness: "Our work" is as current as the last run on both phones. Background
refresh is opportunistic, so open the app on both phones after a calendar change if the result
matters immediately.

As with any CalSync job, this copies work data into a personal iCloud account. Check what your
employer allows before sharing a work calendar.

## Languages

English is the development language. German translations live in `CalSync/Resources/de.lproj`:
`Localizable.strings` for the UI, `Localizable.stringsdict` for plurals, and `InfoPlist.strings`
for the calendar permission text. The English string literals in the SwiftUI views are the
lookup keys, so a new UI string needs an entry in `de.lproj/Localizable.strings`.

## Project layout

```
CalSync.xcodeproj           Xcode project (folders are file-system synchronized; just add files)
CalSync/App                 App entry, background refresh, AppModel (state + persistence)
CalSync/Sync                SyncPlanner (pure diff logic), SyncEngine (EventKit), MappingStore,
                            MeetingIdentity (join-link matching), OrgOnlyLinkFilter (Teams link removal)
CalSync/Models              SyncJob, EventPayload
CalSync/Views               SwiftUI screens
CalSync/Resources/de.lproj  German localization (UI, plurals, permission text)
CalSyncTests                Swift Testing unit tests for the planner, meeting identity, link filter and persistence
Config/Signing.xcconfig     Team ID + bundle ID
Config/Info.plist           Background task IDs, export-compliance flag
Config/ExportOptions.plist  App Store Connect upload options
scripts/testflight.sh       Archive + upload to TestFlight
scripts/make-icon.swift     Regenerates the app icon
scripts/screenshots.sh      Regenerates the App Store screenshots (Debug, demo data)
docs/AppStore.md            Store metadata, screenshots and the remaining App Store Connect steps
docs/privacy.md             Privacy policy in English and German
```

## Setup

1. `Config/Signing.xcconfig` sets the team and bundle ID. They match the team used by BatLog (`fhkf/batcounter`) and Kataster:
   ```
   DEVELOPMENT_TEAM = UZZY9RR34A
   APP_BUNDLE_ID = de.erduman.calsync
   ```
   To override them on one machine, put the values in `Config/Local.xcconfig`. That file is git-ignored and is included automatically.
2. Open `CalSync.xcodeproj` in Xcode and run the app on your iPhone or iPad.

## Publishing to TestFlight

### One-time setup in App Store Connect

1. Under [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list), register the bundle ID. Xcode's automatic signing can also do this for you.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps), create the app with **+ › New App**. Choose platform iOS and the same bundle ID.
3. To upload from the command line or CI, create an API key under **Users and Access › Integrations › App Store Connect API**. Give it the *App Manager* role (or *Admin*, which lets CI create signing certificates), then download the `.p8` file.

### Upload from Xcode

Choose **Product › Archive**, then **Distribute App › App Store Connect › Upload**. Increase the build number each time you upload.

### Upload from the command line

From the project root, run:

```bash
./scripts/testflight.sh
```

The script uses an App Store Connect API key from `~/.config/appstore` when present, and otherwise falls back to the Apple ID signed in to Xcode. To pass a key explicitly:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
./scripts/testflight.sh
```

If the key lives in `~/.config/appstore`, put `keyid`, `issuer` and `AuthKey_*.p8` there and just run `./scripts/testflight.sh`; the script picks them up when `ASC_KEY_*` is not set.

The build number defaults to a UTC timestamp, so it goes up with every upload. Set `MARKETING_VERSION=1.1` to bump the version users see. Set `EXPORT_ONLY=1` to write an `.ipa` to `build/export` instead of uploading.

Once App Store Connect finishes processing the build, it appears in TestFlight. Internal testers can install it right away. External testers need a short Beta App Review first.

The testers are `hakan@erduman.de` and Nina (work address); her older private address remains in the group. See [docs/TestFlight.md](docs/TestFlight.md) for the German setup steps and a ready-to-paste "What to Test" text.

### Upload from GitHub Actions

`.github/workflows/testflight.yml` runs the tests and uploads a build when you start it by hand (Actions › TestFlight › Run workflow). First add these repository settings:

| Kind     | Name                | Value                              |
|----------|---------------------|------------------------------------|
| Secret   | `ASC_KEY_ID`        | API key ID                         |
| Secret   | `ASC_ISSUER_ID`     | Issuer ID                          |
| Secret   | `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8`        |
| Secret   | `DEVELOPMENT_TEAM`  | Team ID                            |
| Variable | `APP_BUNDLE_ID`     | Bundle ID                          |

CI has no signing certificate installed, so it relies on cloud-managed signing through the API key. That needs a key with the Admin role.

## Tests

```bash
xcodebuild test -project CalSync.xcodeproj -scheme CalSync \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## App Store assets

Screenshots live in `docs/app-store/screenshots` (German and English, iPhone 6.9" and
iPad 13") and are regenerated with `./scripts/screenshots.sh`. The script builds a Debug
app, seeds demo data only through the DEBUG-only `--seed-demo` flag and erases the two
simulator devices it uses. Store metadata and the remaining App Store Connect steps are in
[docs/AppStore.md](docs/AppStore.md); the privacy policy draft is in
[docs/privacy.md](docs/privacy.md).

## Privacy

Everything stays on the device. CalSync has no network code and no analytics. It keeps its sync settings and records of the copies it made in the app's Application Support folder. Events live in the calendars you choose; if you pick a shared iCloud calendar, iCloud syncs those entries like any other calendar entry. For the App Store privacy questionnaire, answer "Data Not Collected".
