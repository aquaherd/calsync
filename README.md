# CalSync

CalSync is a small iPhone app that copies events from one calendar to another, for example from a work Outlook/Exchange calendar to a personal iCloud calendar. It's built with SwiftUI and EventKit and targets iOS 26 and later.

## Features

- **Multiple syncs.** Each one copies a source calendar to a writable destination calendar.
- **Updates stay in step.** Re-running a sync updates changed events and removes copies of deleted events. Each occurrence of a recurring event is copied as its own event.
- **No duplicates.** CalSync records which source event each copy came from. If those records are lost (for example after a reinstall), it re-links identical events that are already in the destination.
- **Private mode.** Copies only the time slot, with a custom title such as "Busy".
- **Options.** Choose whether to copy location, notes, URL and alerts. You can skip declined, canceled or all-day events.
- **When it runs.** Syncs run when the app opens, on pull-to-refresh, and every so often in the background (`BGAppRefreshTask`).
- **Undo.** "Remove Copied Events" deletes every event a sync has created.

### Getting Outlook calendars onto the iPhone

CalSync works through iOS's calendar database (EventKit), so the Outlook calendar has to appear in Apple's Calendar app. To set that up, either:

- add the account under **Settings › Apps › Calendar › Calendar Accounts › Add Account › Microsoft Exchange / Outlook.com**, or
- in the Outlook iOS app, go to **Settings › your account › Sync Calendars** and turn it on.

## Project layout

```
CalSync.xcodeproj           Xcode project (folders are file-system synchronized; just add files)
CalSync/App                 App entry, background refresh, AppModel (state + persistence)
CalSync/Sync                SyncPlanner (pure diff logic), SyncEngine (EventKit), MappingStore
CalSync/Models              SyncJob, EventPayload
CalSync/Views               SwiftUI screens
CalSyncTests                Swift Testing unit tests for the planner
Config/Signing.xcconfig     Team ID + bundle ID
Config/Info.plist           Background task IDs, export-compliance flag
Config/ExportOptions.plist  App Store Connect upload options
scripts/testflight.sh       Archive + upload to TestFlight
scripts/make-icon.swift     Regenerates the app icon
```

## Setup

1. `Config/Signing.xcconfig` sets the team and bundle ID. They match the team used by BatLog (`fhkf/batcounter`) and Kataster:
   ```
   DEVELOPMENT_TEAM = UZZY9RR34A
   APP_BUNDLE_ID = de.erduman.calsync
   ```
   To override them on one machine, put the values in `Config/Local.xcconfig`. That file is git-ignored and is included automatically.
2. Open `CalSync.xcodeproj` in Xcode and run the app on your iPhone.

## Publishing to TestFlight

### One-time setup in App Store Connect

1. Under [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list), register the bundle ID. Xcode's automatic signing can also do this for you.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps), create the app with **+ › New App**. Choose platform iOS and the same bundle ID.
3. To upload from the command line or CI, create an API key under **Users and Access › Integrations › App Store Connect API**. Give it the *App Manager* role (or *Admin*, which lets CI create signing certificates), then download the `.p8` file.

### Upload from Xcode

Choose **Product › Archive**, then **Distribute App › App Store Connect › Upload**. Increase the build number each time you upload.

### Upload from the command line

If your Apple ID is signed in to Xcode (as for BatLog's `just testflight-upload`), just run:

```bash
./scripts/testflight.sh
```

Or use an App Store Connect API key:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
./scripts/testflight.sh
```

The build number defaults to a UTC timestamp, so it goes up with every upload. Set `MARKETING_VERSION=1.1` to bump the version users see. Set `EXPORT_ONLY=1` to write an `.ipa` to `build/export` instead of uploading.

Once App Store Connect finishes processing the build, it appears in TestFlight. Internal testers can install it right away. External testers need a short Beta App Review first.

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

## Privacy

Everything stays on the device. CalSync has no network code and no analytics. It keeps its sync settings and records of the copies it made in the app's Application Support folder. For the App Store privacy questionnaire, answer "Data Not Collected".
