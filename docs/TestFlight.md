# TestFlight: CalSync für Hakan und Nina

Diese Datei beschreibt den Stand der TestFlight-Vorbereitung und die letzten Schritte,
die nur mit Apple-ID bzw. App-Store-Connect-Zugang möglich sind.

## Was vorbereitet ist

- Die App-Oberfläche ist vollständig auf Deutsch und Englisch verfügbar.
  Die deutschen Texte liegen in `CalSync/Resources/de.lproj/` (`Localizable.strings`,
  `Localizable.stringsdict`, `InfoPlist.strings`).
- Der Systemtext für den Kalenderzugriff ist auf Deutsch übersetzt.
- Deutsche Pluralformen für „Aktuell (1 Termin / 2 Termine)“ und
  „1 Termin entfernt / 2 Termine entfernt“ sind enthalten.
- Unit-Tests laufen durch, der Release-Build für iOS kompiliert.
- Die Build-Nummer setzt `scripts/testflight.sh` automatisch auf einen UTC-Zeitstempel,
  sie steigt also bei jedem Upload.

## Neu in diesem Build

- **Kalender zusammenführen:** Eine Synchronisierung kann mehrere Quellkalender haben.
  Ein Termin, der in mehreren Quellen liegt, wird nur einmal kopiert. Erkannt wird er am
  Beitrittslink (Teams, Zoom, Google Meet) oder an Titel und Startzeit. Die erste Quelle
  bestimmt Titel und Details.
- **Sicherer bei leeren Quellen:** Wenn ein Quellkalender, der vorher Termine hatte,
  plötzlich leer ist, stoppt CalSync das Löschen und fragt nach.
- **Geteilte Ziele:** Ein Zielkalender kann ein geteilter iCloud-Kalender sein. Das Teilen
  selbst passiert einmalig in der Kalender-App; EventKit kann keine Freigaben anlegen.

## Testgruppe

Stand: 27. Oktober 2026.

| Name          | E-Mail                              | Gruppe                              |
|---------------|-------------------------------------|-------------------------------------|
| Hakan Erduman | hakan@erduman.de                    | intern „Test“ (Build installiert)   |
| Nina          | [redacted] | extern „Extern“ (nach Beta-Prüfung) |

- Die interne Gruppe „Calsync“ wurde entfernt; „Test“ bleibt für Hakan.
- Nina ist als externe Testerin in „Extern“ eingetragen. Für externe Tests braucht sie
  kein App-Store-Connect-Benutzerkonto.
- Build **1.0 (2610251841)** wurde am 25.10.2026 zur Beta-App-Prüfung eingereicht.
  Der neue Build mit der Zusammenführungsfunktion wird nach dem Upload ebenfalls zur
  Beta-Prüfung eingereicht.

### Stammdaten in App Store Connect

- Kategorie: **Produktivität**
- Altersfreigabe: **4+** (172 Länder oder Regionen; Brasilien Alle, Südkorea 00+, Vietnam)
- Inhaltsrechte: keine Inhalte von Drittanbietern
- App-Datenschutz: **Keine Daten erfasst** (veröffentlicht)
- Testinformationen: deutsche Beta-Beschreibung, Feedback-Adresse und Kontakt hinterlegt
- Verschlüsselung: `ITSAppUsesNonExemptEncryption = NO`, kein Export-Compliance-Fragebogen nötig

### So funktioniert der externe Weg

1. Build in eine externe Gruppe legen; der erste Build geht automatisch in die Beta-App-Prüfung.
2. Nach der Freigabe erhalten die Tester:innen eine Einladung per E-Mail.
3. Sie installieren die TestFlight-App und akzeptieren die Einladung dort.

## Upload

Voraussetzung: Apple-ID in Xcode › Einstellungen › Accounts angemeldet **oder** ein
App-Store-Connect-API-Key mit Rolle „App Manager“.

```bash
# Variante 1: Xcode-Account
./scripts/testflight.sh

# Variante 2: API-Key
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
./scripts/testflight.sh

# Nur bauen, nicht hochladen
EXPORT_ONLY=1 ./scripts/testflight.sh
```

Danach erscheint der Build nach der Verarbeitung in TestFlight. Für den ersten Upload
muss in App Store Connect ein App-Eintrag mit der Bundle-ID `de.erduman.calsync` existieren.

## Bekannte Fehler beim ersten Upload

### „PLA Update available“

```
Unable to process request - PLA Update available
```

Die aktualisierte Apple Developer Program License Agreement wurde noch nicht akzeptiert.
Nur der Account Holder kann sie unter [developer.apple.com/account](https://developer.apple.com/account)
bzw. App Store Connect › Business › Program License Agreement akzeptieren.

### „Copy failed“ beim Export

```
error: exportArchive Copy failed
** EXPORT FAILED **
```

Xcode verpackt das IPA mit `/usr/bin/rsync` (openrsync). openrsync startet seine
Serverseite über `PATH`; liegt dort ein GNU-rsync aus MacPorts oder Homebrew vorn,
scheitert es an `-E`:

```
rsync: on remote machine: --extended-attributes: unknown option
```

`scripts/testflight.sh` setzt deshalb `/usr/bin` an den Anfang von `PATH`. Wer
`xcodebuild -exportArchive` von Hand aufruft, macht dasselbe:

```bash
PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive …
```

### „The App Name you entered is already being used“

```
409 ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE.DIFFERENT_ACCOUNT
The App Name you entered is already being used … on a different account.
```

App-Store-Namen sind weltweit eindeutig. „CalSync“ gehört bereits einem anderen Account.
Lösung: App-Eintrag in App Store Connect manuell anlegen und dabei einen freien Namen
wählen, zum Beispiel „CalSync – Kalender kopieren“, „CalSync: Termine kopieren“ oder
„CalSync Calendar Copy“. Der Name auf dem Home-Bildschirm bleibt unabhängig davon
`CalSync` (`CFBundleDisplayName`). Alternativ im Xcode-Dialog „App Record erstellen“
das Feld **App Name** ändern.

## „Was soll getestet werden?“ (zum Einfügen in TestFlight)

> CalSync kopiert Termine aus einem oder mehreren Quellkalendern in einen Zielkalender,
> zum Beispiel von Outlook nach iCloud. Bitte prüfe:
>
> - Kalenderzugriff erlauben und eine Synchronisierung mit Quelle und Ziel anlegen.
> - Einmal „Alle synchronisieren“ antippen: Werden Termine korrekt kopiert?
> - Einen Termin in der Quelle ändern: Wird die Kopie beim nächsten Sync aktualisiert?
> - Einen Termin in der Quelle löschen: Verschwindet die Kopie?
> - **Zwei Quellkalender zusammenführen** („Von“ › Kalender hinzufügen). Ein Termin, der in
>   beiden Quellen liegt, soll im Ziel nur einmal erscheinen, auch wenn die Titel leicht
>   abweichen. Der Beitrittslink (Teams/Zoom) ist dabei das wichtigste Erkennungsmerkmal.
> - Einen Termin nur im ersten Quellkalender löschen: Bleibt die Kopie erhalten, solange der
>   zweite Quellkalender den Termin noch enthält?
> - Einen Quellkalender vorübergehend leeren oder das Konto abmelden: CalSync soll das Löschen
>   stoppen und nachfragen, statt die Kopien sofort zu entfernen.
> - **Geteiltes Ziel:** Zielkalender in iCloud für beide freigeben (Kalender › Info › Teilen)
>   und auf dem zweiten Gerät prüfen, ob die Kopien ankommen.
> - Den privaten Modus testen: Steht in der Kopie nur der Zeitraum mit dem Titel „Beschäftigt“?
> - „URL kopieren“ ausschalten und einen Termin mit Teams-Beitrittslink prüfen: Der Link und die Beitrittstexte sollen aus Notizen und Ort verschwinden, Meeting-ID und Passcode bleiben.
> - Quelle oder Ziel ändern: Fragt CalSync, ob die alten Kopien entfernt werden sollen?
> - „Kopierte Termine entfernen“ ausprobieren.
> - Die App schließen und wieder öffnen: Läuft die Synchronisierung automatisch?
>
> Rückmeldungen gern mit Screenshot und iOS-Version an hakan@erduman.de.
