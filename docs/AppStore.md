# CalSync – App Store readiness

Operational notes for shipping CalSync 1.0 on the App Store. Written 18 November 2026,
after build **2611172329** was uploaded.

Bundle ID `de.erduman.calsync`, team `UZZY9RR34A`, iOS 26 or later, iPhone and iPad.

## Status

### Done in the repository

- **Build 1.0 (2611172329)** was uploaded to App Store Connect on 18 November 2026 and is
  processing. It adds native iPad support. The previous external build 1.0 (2611022247)
  is still available to testers.
- **iPad layout.** Two columns when the window is wide enough: syncs on the left, editor
  on the right. In narrow windows, Split View and Slide Over the app falls back to the
  single-column layout instead of presenting an editor unasked. ⌘N creates a sync, ⌘R runs
  Sync All. The iPhone layout is unchanged.
- **Screenshots** for iPhone 6.9" and iPad 13", in German and English, under
  `docs/app-store/screenshots/`. See [Screenshots](#screenshots).
- **Privacy manifest** `CalSync/PrivacyInfo.xcprivacy`: no tracking, no collected data
  types, no required-reason APIs.
- **German and English UI**, including the German calendar permission text.
- **App icon** in `CalSync/Assets.xcassets/AppIcon.appiconset`.
- **Encryption:** `ITSAppUsesNonExemptEncryption = NO` in the target build settings, so
  App Store Connect does not ask the export-compliance questions.
- **Privacy policy draft:** [docs/privacy.md](privacy.md). It still needs a public URL;
  see [Privacy policy URL](#privacy-policy-url).

### Only in App Store Connect

These steps need the account holder (or a team member with the matching role); no code
change can do them:

- Make the privacy policy publicly reachable and paste its URL into the app record and
  the TestFlight test information.
- Add build 2611172329 to the external group **Extern** and submit it for Beta App Review.
- Fill the Beta App Review contact details, including a phone number. Use the account
  holder's number; do not put a placeholder in the review notes.
- Create the 1.0 App Store version, paste the metadata below, upload the screenshots,
  attach the build and submit for App Review.
- Accept any pending Apple Developer Program License Agreement.

Already set in App Store Connect and unchanged by this document: category Productivity,
age rating 4+, App Privacy “Data Not Collected”, content rights “no third-party content”,
internal group **Test**, external group **Extern**, and build 2611022247 approved for
external testing.

## Screenshots

Apple requires an iPhone 6.9" set and, because CalSync supports iPad, an iPad 13" set.
Both localizations need both sets. App Store Connect accepts up to 10 images per slot;
CalSync has two per slot, uploaded in the order shown.

| Language | Slot | Files (relative to the repository root) | Pixels | Upload order |
|---|---|---|---|---|
| German | iPhone 6.9" | `docs/app-store/screenshots/de/iphone-6.9/01-syncs.png`<br>`docs/app-store/screenshots/de/iphone-6.9/02-sync-editor.png` | 1320 × 2868 | 1, 2 |
| German | iPad 13" | `docs/app-store/screenshots/de/ipad-13/01-workspace.png`<br>`docs/app-store/screenshots/de/ipad-13/02-new-sync.png` | 2064 × 2752 | 1, 2 |
| English | iPhone 6.9" | `docs/app-store/screenshots/en/iphone-6.9/01-syncs.png`<br>`docs/app-store/screenshots/en/iphone-6.9/02-sync-editor.png` | 1320 × 2868 | 1, 2 |
| English | iPad 13" | `docs/app-store/screenshots/en/ipad-13/01-workspace.png`<br>`docs/app-store/screenshots/en/ipad-13/02-new-sync.png` | 2064 × 2752 | 1, 2 |

What the images show:

- **iPhone 01-syncs:** the sync list with two demo syncs and their last results.
- **iPhone 02-sync-editor:** the editor for a single sync, From and To, time range and
  copy options.
- **iPad 01-workspace:** the split view with the sync list on the left and the editor open
  on the right.
- **iPad 02-new-sync:** a new, empty sync in the detail column.

The images are plain simulator screenshots with the system status bar set to 9:41 and a
full battery. There are no marketing overlays, frames or captions. The German set is
captured with the simulator language set to German, the English set with English, so the
screenshots match the App Store localization they are uploaded to. All files are PNG,
RGB, without an alpha channel.

### Regenerating the screenshots

From the repository root:

```bash
./scripts/screenshots.sh
```

The script builds the app for the simulator, then erases, reboots and reinstalls it on two
simulator devices from the iOS 26.4 runtime: **iPhone 17 Pro Max** and **iPad Pro 13-inch
(M5)**. `simctl erase` deletes everything on those two simulators. It also deletes every
existing PNG under `docs/app-store/screenshots/` before capturing, and fails if it does
not end up with exactly eight images.

The demo calendars, events and syncs come from `CalSync/App/DemoData.swift`, which is
compiled only into Debug builds and runs only with the `--seed-demo` launch argument. A
Release build contains neither the demo data nor the launch flags; nothing in this script
or the app can seed demo data in a shipping build.

Run the script once at a time. Two concurrent runs share the same two simulator devices:
they erase and re-language each other, and the resulting PNGs can end up in the wrong
language. Check the output before uploading; the German images must show German UI.

**Simulator artifact:** the calendar rows show the account title **Default** next to each
calendar name. That is the name of the local account on a freshly erased simulator, not a
CalSync label. On a real device the same position shows iCloud, Exchange or On My iPhone.
Do not “fix” this in the screenshots.

## App Store listing copy

The blocks below are ready to paste. Counts are characters excluding a trailing newline,
measured with a plain `len()` over the exact strings.

### App name (limit 30)

**Keep the name already saved on the existing CalSync app record.** App Store names are
unique worldwide and “CalSync” belongs to another account, so the record was created under
a different name. Do not create a second record to get a different name, and do not rename
the app to plain “CalSync” — App Store Connect will reject it. The home-screen name is
independent of this and stays **CalSync** (`CFBundleDisplayName`).

If the name ever has to be chosen again, these alternatives fit the 30-character limit:

| Name | Characters |
|---|---|
| CalSync – Kalender kopieren | 27 |
| CalSync: Termine kopieren | 25 |
| CalSync Calendar Copy | 21 |

### Subtitle (limit 30)

German (28):

```
Termine automatisch spiegeln
```

English (30):

```
Mirror calendars automatically
```

### Promotional text (limit 170)

German (169):

```
Termine von Outlook nach iCloud spiegeln – ohne Konto und ohne Netzwerk. Kalender zusammenführen, Änderungen übernehmen, Kopien verwalten. Jetzt auch nativ auf dem iPad.
```

English (147):

```
Mirror events from Outlook to iCloud — no account, no network. Merge calendars, keep copies in step and remove them safely. Now native on iPad too.
```

### Description (limit 4000)

Counts: German 2055, English 1899 (limit 4000).

German:

```
CalSync kopiert Termine aus einem oder mehreren Kalendern in einen Zielkalender – zum Beispiel von Outlook nach iCloud. Alles bleibt auf deinem Gerät: keine Anmeldung, kein Konto, kein Netzwerkzugriff.

• Mehrere Synchronisierungen: Jede kopiert eine oder mehrere Quellen in ein Ziel.
• Kalender zusammenführen: Liegt ein Meeting in mehreren Quellen, wird es einmal kopiert. Der Beitrittslink (Teams, Zoom, Google Meet) erkennt dasselbe Meeting auch bei abweichenden Titeln; ohne Link zählen Titel und Startzeit.
• Ziel anlegen: „Neuer Kalender …“ erstellt einen Kalender in iCloud oder „Auf meinem iPhone“. Geteilt wird er einmalig in der Kalender-App.
• Bleibt aktuell: Änderungen an der Quelle werden übernommen, Kopien gelöschter Termine entfernt. Jede Wiederholung eines Serientermins wird als eigener Termin kopiert.
• Sicher entfernen: Würde ein Lauf mehr als die Hälfte der Kopien löschen oder liefert eine Quelle plötzlich keine Termine, stoppt CalSync und fragt nach. Lief der Lauf im Hintergrund, erscheint die Frage beim nächsten Öffnen.
• Privater Modus: Kopiert nur den Zeitraum mit einem eigenen Titel wie „Beschäftigt“.
• Kopieroptionen: Ort, Notizen, URL und Erinnerungen einzeln wählbar; abgelehnte, abgesagte und ganztägige Termine lassen sich überspringen.
• Teams-Links: Ist „URL kopieren“ aus, verschwinden Beitrittslinks und Beitrittstexte aus Notizen und Ort; Meeting-ID und Passcode bleiben.
• Automatisch: Synchronisierungen laufen beim Öffnen der App, per Ziehen zum Aktualisieren und regelmäßig im Hintergrund.
• iPad: Liste und Editor nebeneinander, angepasst an die Fenstergröße; funktioniert auch in Split View und Slide Over. ⌘N öffnet eine neue Synchronisierung, ⌘R startet „Alle synchronisieren“.
• iPhone: bleibt wie gewohnt einspaltig.
• Datenschutz: Kalenderzugriff über EventKit, nur um zwischen deinen gewählten Kalendern zu kopieren. Keine Netzwerkverbindung, keine Analyse, keine Werbung, kein Tracking.

CalSync braucht vollen Kalenderzugriff. Ohne ihn kann die App keine Termine lesen und keine Kopien schreiben.
```

English:

```
CalSync copies events from one or more calendars into a destination calendar — for example from Outlook to iCloud. Everything stays on your device: no sign-in, no account, no network access.

• Multiple syncs: each one copies one or more sources into a destination.
• Merge calendars: if a meeting appears in more than one source, it is copied once. A join link (Teams, Zoom, Google Meet) identifies the same meeting even when the titles differ; without one, the normalized title and start time are used.
• Create the destination: “New Calendar…” creates a calendar in iCloud or On My iPhone. Sharing it remains a one-time step in the Calendar app.
• Stays current: changes in the source are applied and copies of deleted events are removed. Each occurrence of a recurring event is copied as its own event.
• Safe removals: if a run would delete more than half of the copies, or a source suddenly returns no events, CalSync stops and asks. After a background run, the question appears the next time you open the app.
• Private mode: copies only the time slot, with a custom title such as “Busy”.
• Copy options: location, notes, URL and alerts can be chosen separately; declined, canceled and all-day events can be skipped.
• Teams links: with “Copy URL” off, join links and their join boilerplate disappear from notes and location; the meeting ID and passcode remain.
• Automatic: syncs run when the app opens, on pull-to-refresh, and periodically in the background.
• iPad: list and editor side by side, adapted to the window size; works in Split View and Slide Over too. ⌘N opens a new sync, ⌘R runs Sync All.
• iPhone: stays single-column, as before.
• Privacy: calendar access through EventKit, only to copy between the calendars you choose. No network connection, no analytics, no ads, no tracking.

CalSync requires full calendar access. Without it the app cannot read events or write copies.
```

### Keywords (limit 100)

German (80):

```
kalender,synchronisieren,kopieren,outlook,icloud,exchange,termine,spiegeln,teams
```

English (62):

```
calendar,sync,copy,outlook,icloud,exchange,events,mirror,teams
```

Do not add spaces after the commas; they count against the limit and are not needed.

### What's New (limit 4000)

1.0 is the first release, so App Store Connect may not show a “What's New” field for it.
Keep this text for TestFlight and for the first update.

German:

```
CalSync ist jetzt auch nativ auf dem iPad zu Hause: Liste und Editor nebeneinander, angepasst an jede Fenstergröße, inklusive Split View und Slide Over. ⌘N öffnet eine neue Synchronisierung, ⌘R startet „Alle synchronisieren“. Nach dem Sichern bleibt die Auswahl erhalten. Auf dem iPhone bleibt alles wie gewohnt.
```

English:

```
CalSync is now native on iPad too: list and editor side by side, adapted to any window size, including Split View and Slide Over. ⌘N opens a new sync and ⌘R runs Sync All. Saving keeps the sync selected. On iPhone everything stays as before.
```

### Links and classification

| Field | Value |
|---|---|
| Support URL | https://github.com/fhkf/calsync/issues |
| Marketing URL | https://github.com/fhkf/calsync |
| Copyright | © 2026 Hakan Erduman |
| Primary category | Productivity |
| Age rating | 4+ |
| Price | Free (pricing, tax and banking are out of scope here) |

Both URLs must be reachable without a login. The support URL points at the issue tracker,
so the repository and its Issues tab have to stay public.

## Privacy policy URL

**This is a blocker for external TestFlight and for App Store submission.** Apple requires
a privacy policy that anyone can open without signing in. A link to a private repository
file is not enough.

The text is ready in [docs/privacy.md](privacy.md). There are two ways to publish it:

1. **GitHub Pages, conditional example.** If Pages is enabled for this repository with
   *Deploy from a branch* → `main` → `/docs`, GitHub publishes `docs/privacy.md` as
   `https://fhkf.github.io/calsync/privacy.html`. That URL is an example, not a promise:
   check it in a private browser window before pasting it anywhere. Enabling Pages also
   publishes the other files in `docs/`, including this one.
2. **The developer's own domain.** Host the same Markdown or a rendered HTML page at a
   stable public URL there. Use this if Pages is not enabled or the GitHub URL does not
   resolve.

Paste the verified URL into:

- App Store Connect › the app › **App Information** › **Privacy Policy URL**;
- TestFlight › **Test Information** › **Privacy Policy URL**.

External beta review and App Review both check that the page loads and matches the app.
After the policy is live, the checklist item below can be ticked.

## App Review information

### App Review notes (paste-ready)

```
CalSync copies events between calendars that the user chooses, for example from an Outlook/Exchange calendar to iCloud.

Calendar access: CalSync requests full access to calendars through EventKit. iOS requires full access for an app that reads existing events; CalSync uses it only to read the selected source calendars and to write, update and delete the copies it creates in the selected destination calendar. There is no other use of calendar data.

No sign-in or demo account: the app has no accounts, no login, no in-app purchases and no network code. CalSync itself transmits nothing; calendar data is read and written through EventKit on the device.

Background work: enabled syncs also run through BGAppRefreshTask. iOS schedules these runs opportunistically; they are not needed to review the app. A background run cannot remove a large number of events without confirmation.

How to test:
1. Launch the app and allow full calendar access.
2. Tap + (or ⌘N on iPad), choose a source calendar under “From” and a writable calendar under “To”, then tap “Save”.
3. Tap “Sync All” (or ⌘R). Open the destination calendar in Calendar: the events from the source should be there.
4. Change an event in the source, run “Sync All” again: the copy is updated. Delete a source event and sync again: the copy is removed.
5. Optional: turn on “Private (Busy Only)” to see copies that contain only the time slot and a custom title.
6. On iPad, rotate the device and resize the window; try Split View and Slide Over. At regular width the sync list and editor sit side by side. In narrow widths and Slide Over the app uses its single-column layout; changing the size never presents an editor by itself.

The app name in App Store Connect differs from the home-screen name, which is “CalSync”. “CalSync” was already taken worldwide by another account, so the existing record uses a different name. The bundle ID is de.erduman.calsync.
```

### Contact fields

- Contact name: Hakan Erduman
- Email: hakan@erduman.de
- Phone: the account holder must enter a reachable number in App Store Connect. It is not
  stored in this repository, and a placeholder must not be used.

## App Privacy answers

| Question | Answer | Why |
|---|---|---|
| Data collection | **Data Not Collected** | Calendar data is read and written through EventKit on the device. CalSync transmits nothing. |
| Tracking | **No** | No analytics, ads, attribution or cross-app/website tracking. `NSPrivacyTracking` is `false`. |
| Third-party SDKs | **None** | No packages, no ad or analytics SDKs, no server. |
| Data linked to the user | **None** | No account, no identifiers sent anywhere. |

`CalSync/PrivacyInfo.xcprivacy` matches these answers: `NSPrivacyTracking` false, an empty
`NSPrivacyCollectedDataTypes` array and no required-reason API entries. The privacy policy
describes the same behaviour; keep the two in sync if the app changes.

## TestFlight external testing

The external group is **Extern**. A new build for that group goes through Beta App Review
first. Fill the test information below, then submit build 2611172329.

### Beta App Description (DE)

```
CalSync kopiert Termine aus einem oder mehreren Quellkalendern in einen Zielkalender, zum Beispiel von Outlook nach iCloud. Die App läuft auf iPhone und iPad. Alles bleibt auf dem Gerät: keine Anmeldung, kein Konto, kein Netzwerkzugriff, keine Analyse.
```

### Beta App Description (EN)

```
CalSync copies events from one or more source calendars into a destination calendar, for example from Outlook to iCloud. The app runs on iPhone and iPad. Everything stays on the device: no sign-in, no account, no network access, no analytics.
```

### What to Test (DE)

```
CalSync kopiert Termine aus einem oder mehreren Quellkalendern in einen Zielkalender, zum Beispiel von Outlook nach iCloud. Bitte prüfe:

iPhone:
- Kalenderzugriff erlauben und eine Synchronisierung mit Quelle und Ziel anlegen.
- Einmal „Alle synchronisieren“ antippen: Werden Termine korrekt kopiert?
- Einen Termin in der Quelle ändern: Wird die Kopie beim nächsten Sync aktualisiert?
- Einen Termin in der Quelle löschen: Verschwindet die Kopie?
- Zwei Quellkalender zusammenführen („Von“ › Kalender hinzufügen). Ein Termin, der in beiden Quellen liegt, soll im Ziel nur einmal erscheinen, auch wenn die Titel leicht abweichen. Der Beitrittslink (Teams/Zoom) ist dabei das wichtigste Erkennungsmerkmal.
- Einen Termin nur im ersten Quellkalender löschen: Bleibt die Kopie erhalten, solange der zweite Quellkalender den Termin noch enthält?
- Einen Quellkalender vorübergehend leeren oder das Konto abmelden: CalSync soll das Löschen stoppen und nachfragen, statt die Kopien sofort zu entfernen.
- Geteiltes Ziel: Zielkalender in iCloud für beide freigeben (Kalender › Info › Teilen) und auf dem zweiten Gerät prüfen, ob die Kopien ankommen.
- Neuen Zielkalender anlegen: Im Editor unter „Nach“ › „Neuer Kalender …“ einen Kalender in iCloud erstellen, als Ziel wählen und einen Termin dorthin synchronisieren.
- Den privaten Modus testen: Steht in der Kopie nur der Zeitraum mit dem Titel „Beschäftigt“?
- „URL kopieren“ ausschalten und einen Termin mit Teams-Beitrittslink prüfen: Der Link und die Beitrittstexte sollen aus Notizen und Ort verschwinden, Meeting-ID und Passcode bleiben.
- Quelle oder Ziel ändern: Fragt CalSync, ob die alten Kopien entfernt werden sollen?
- „Kopierte Termine entfernen“ ausprobieren.
- Die App schließen und wieder öffnen: Läuft die Synchronisierung automatisch?

iPad:
- Die App auf dem iPad öffnen: Links die Liste, rechts der Editor der ausgewählten Synchronisierung.
- Eine Synchronisierung auswählen, etwas ändern und sichern: Bleibt sie danach ausgewählt?
- „Abbrechen“: Wird die Auswahl geleert, ohne dass ein Editor als Sheet aufpoppt?
- Das Fenster verkleinern und Split View ausprobieren: Der Editor bleibt neben der Liste. In Slide Over wechselt die App in die einspaltige Ansicht; ein Wechsel der Größe öffnet keinen Editor ungefragt.
- Das iPad drehen (Hoch- und Querformat): Die Ansicht bleibt bedienbar.
- Mit Hardware-Tastatur ⌘N und ⌘R testen.
- Die Oberfläche auf Deutsch und auf Englisch prüfen (Einstellungen › Allgemein › Sprache & Region bzw. App-Sprache).

Rückmeldungen gern mit Screenshot, Gerät, iOS-Version und Angabe, ob iPhone oder iPad, an hakan@erduman.de.
```

### Test information

| Field | Value |
|---|---|
| Beta App Description | German block above (primary), English block as the English localization |
| What to Test | German block above |
| Feedback email | hakan@erduman.de |
| Privacy Policy URL | the public URL from [Privacy policy URL](#privacy-policy-url) — required before external testing |
| Contact first/last name | Hakan Erduman |
| Contact email | hakan@erduman.de |
| Contact phone | account holder only; do not invent one |

The German What-to-Test text above is also maintained in [TestFlight.md](TestFlight.md).

## Manual checklist

Repository work:

- [x] Build 2611172329 uploaded (18 November 2026) and processing.
- [x] German and English screenshots generated for iPhone 6.9" and iPad 13".
- [x] Check all eight images (18 November 2026): the German set shows German UI, the
      English set shows English UI, both show 9:41 and a full battery, and none has an
      alpha channel.
- [x] Privacy manifest, German localization, app icon and encryption flag in place.
- [x] Privacy policy text written in [privacy.md](privacy.md).

App Store Connect:

- [ ] Publish the privacy policy (Pages or own domain), open it logged out, and paste the
      URL into App Information and Test Information.
- [ ] Add the German screenshot set to the German localization: iPhone 6.9" first, then
      iPad 13", in file order.
- [ ] Add the English screenshot set to the English localization in the same way.
- [ ] Wait until 2611172329 finishes processing, then add it to the external group
      **Extern**.
- [ ] Fill the Beta App Review contact details, including the phone number, and submit the
      build for Beta App Review.
- [ ] After approval: install it through TestFlight on an iPhone and an iPad and walk
      through the iPad checks above.
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in the target
      build settings; if App Store Connect still shows a question, answer “No”.
- [ ] Create the 1.0 App Store version, paste name, subtitle, promotional text,
      description and keywords, attach the build, upload the screenshots and submit for
      App Review.

Already done in App Store Connect and not to be repeated: category Productivity, age
rating 4+, App Privacy “Data Not Collected”, content rights with no third-party content,
export compliance, internal group **Test**, external group **Extern**, build 2611022247
approved for external testing.

## Not covered here

App Store preview videos, promotional artwork, custom product pages, pricing, tax and
banking are out of scope for this document. So is the App Store name decision itself:
the existing record's name is kept, and the alternatives above are only for the case where
a name has to be entered again.
