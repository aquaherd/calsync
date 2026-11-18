# CalSync Privacy Policy

Effective 18 November 2026

CalSync is an app for iPhone and iPad that copies events from calendars you choose
to another calendar you choose. It is made by Hakan Erduman. Questions and requests:
**hakan@erduman.de**.

## What CalSync does

You create a sync, pick one or more source calendars and a destination calendar, and
CalSync copies the events in the selected time range. Later runs update changed copies
and remove copies of deleted events. Everything happens on your device.

## Calendar access

CalSync asks for full access to your calendars through Apple's EventKit framework. iOS
requires this access level for an app that reads existing events. CalSync uses it only to
read the calendars you select as sources and to write, update and delete the copies it
made in the destination calendar you select. It does not read events from calendars you
did not select for a sync and does not use calendar data for anything else.

## What is stored on the device

CalSync keeps its data in its own Application Support folder:

- your sync settings: source and destination calendars, time range, copy options and the
  result of the last run;
- a record of the copies it made: the identifier of the destination event, the copied
  start and end time, and a SHA-256 fingerprint of the copied fields.

Notes, locations and URLs are not stored a second time. The fingerprint is a one-way
digest used to notice when a source event changed. If you make an iCloud or computer
backup of your device, iOS may include this app folder in that backup; CalSync itself
does not send it anywhere.

## No network, no tracking

CalSync has no network code. It does not connect to the internet, does not use analytics
or advertising, does not track you across apps or websites, and contains no third-party
SDKs. No account is required. The App Store privacy label is **Data Not Collected**.

## iCloud and shared calendars

If you choose an iCloud or shared calendar as a source or destination, Apple's calendar
service syncs those events between your devices and with the people the calendar is
shared with. That is part of iOS and the Calendar app, not something CalSync does. The
developer has no access to your calendars or to Apple's service.

## Background refresh

CalSync can run enabled syncs in the background with `BGAppRefreshTask`. iOS decides
when that happens. A background run cannot wipe a destination: a removal that looks too
large is stopped and waits for your confirmation the next time you open the app.

## Permissions and revocation

You can change or revoke calendar access at any time under **Settings › Apps › Calendar ›
CalSync**. Without access, CalSync cannot read or write events. Copies that already exist
stay in the destination calendar.

## Deleting your data

Deleting CalSync from your device removes its local settings and its record of the copies
it made. The copied events themselves stay in the calendars. Remove them before deleting
the app with **Remove Copied Events** in the sync editor, or delete them in the Calendar
app afterwards.

## Children

CalSync is not directed at children and collects no personal data from anyone.

## Changes

If this policy changes, the updated version is published in this repository with a new
effective date. Material changes will be noted in the release notes.

## Contact

Hakan Erduman
hakan@erduman.de

---

# CalSync Datenschutzerklärung

Gültig ab 18. November 2026

CalSync ist eine App für iPhone und iPad, die Termine aus von dir gewählten Kalendern in
einen anderen von dir gewählten Kalender kopiert. Verantwortlich ist Hakan Erduman.
Fragen und Anliegen: **hakan@erduman.de**.

## Was CalSync macht

Du legst eine Synchronisierung an, wählst einen oder mehrere Quellkalender und einen
Zielkalender, und CalSync kopiert die Termine im gewählten Zeitraum. Spätere Läufe
aktualisieren geänderte Kopien und entfernen Kopien gelöschter Termine. Alles geschieht
auf deinem Gerät.

## Kalenderzugriff

CalSync fragt über Apples EventKit-Framework nach vollem Zugriff auf deine Kalender. iOS
verlangt diese Zugriffsstufe für Apps, die vorhandene Termine lesen. CalSync nutzt sie nur,
um die von dir als Quelle gewählten Kalender zu lesen und die Kopien im gewählten
Zielkalender zu schreiben, zu aktualisieren und zu löschen. Termine aus Kalendern, die du
keiner Synchronisierung zuordnest, werden nicht gelesen; die Kalenderdaten werden für
nichts anderes verwendet.

## Was auf dem Gerät gespeichert wird

CalSync speichert seine Daten im eigenen Application-Support-Ordner:

- deine Einstellungen zur Synchronisierung: Name, Quell- und Zielkalender, Zeitraum,
  Kopieroptionen und das Ergebnis des letzten Laufs;
- einen Nachweis der erstellten Kopien: die Kennung des Termins im Ziel, die kopierte
  Start- und Endzeit und einen SHA-256-Fingerabdruck der kopierten Felder.

Notizen, Orte und URLs werden nicht ein zweites Mal gespeichert. Der Fingerabdruck ist
eine Einweg-Prüfsumme, mit der CalSync erkennt, ob sich ein Quelltermin geändert hat. Wenn
du ein iCloud- oder Computer-Backup deines Geräts erstellst, kann iOS diesen App-Ordner
in das Backup aufnehmen; CalSync selbst sendet ihn nirgendwohin.

## Kein Netzwerk, kein Tracking

CalSync enthält keinen Netzwerkcode. Die App verbindet sich nicht mit dem Internet,
verwendet keine Analyse- oder Werbedienste, verfolgt dich nicht über Apps oder Websites
hinweg und enthält keine SDKs von Drittanbietern. Ein Konto ist nicht nötig. Das
Datenschutz-Label im App Store lautet **Keine Daten erfasst**.

## iCloud und geteilte Kalender

Wenn du einen iCloud- oder geteilten Kalender als Quelle oder Ziel wählst, synchronisiert
Apples Kalenderdienst diese Termine zwischen deinen Geräten und mit den Personen, mit
denen der Kalender geteilt ist. Das gehört zu iOS und zur Kalender-App, nicht zu CalSync.
Der Entwickler hat keinen Zugriff auf deine Kalender oder auf Apples Dienst.

## Hintergrundaktualisierung

CalSync kann aktivierte Synchronisierungen mit `BGAppRefreshTask` im Hintergrund
ausführen. Wann das geschieht, entscheidet iOS. Ein Hintergrundlauf kann einen
Zielkalender nicht leeren: Ein zu großer Löschvorgang wird gestoppt und wartet beim
nächsten Öffnen der App auf deine Bestätigung.

## Berechtigungen und Widerruf

Du kannst den Kalenderzugriff jederzeit unter **Einstellungen › Apps › Kalender › CalSync**
ändern oder widerrufen. Ohne Zugriff kann CalSync keine Termine lesen oder schreiben.
Bereits vorhandene Kopien bleiben im Zielkalender.

## Daten löschen

Wenn du CalSync vom Gerät löschst, werden die lokalen Einstellungen und der Nachweis der
erstellten Kopien entfernt. Die kopierten Termine selbst bleiben in den Kalendern. Entferne
sie vor dem Löschen der App mit **Kopierte Termine entfernen** im Editor der
Synchronisierung oder danach in der Kalender-App.

## Kinder

CalSync richtet sich nicht an Kinder und erhebt von niemandem personenbezogene Daten.

## Änderungen

Wenn sich diese Erklärung ändert, wird die aktualisierte Fassung in diesem Repository mit
einem neuen Gültigkeitsdatum veröffentlicht. Auf wesentliche Änderungen wird in den
Versionshinweisen hingewiesen.

## Kontakt

Hakan Erduman
hakan@erduman.de
