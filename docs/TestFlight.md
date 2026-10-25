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

## Testgruppe

Vorgesehen sind zwei Tester:

| Name          | E-Mail             | Art                   |
|---------------|--------------------|-----------------------|
| Hakan Erduman | hakan@erduman.de   | intern (Account-Inhaber) |
| Nina          | [redacted]    | intern oder extern    |

**Intern** (Builds sofort verfügbar, keine Beta-Prüfung):

1. App Store Connect › Benutzer und Zugriff › Nina mit ihrer Apple-ID einladen.
   Die Rolle „Entwickler“ oder „Marketing“ genügt für interne Tests.
2. TestFlight › Interne Tests › Gruppe anlegen und beide E-Mail-Adressen zuordnen.
3. Nach dem Upload den Build für die interne Gruppe freigeben.

**Extern** (falls Nina nicht ins Team soll):

1. TestFlight › Externe Tests › Gruppe anlegen, beide E-Mail-Adressen eintragen.
2. Den ersten Build zur Beta-App-Review einreichen (dauert meist wenige Stunden).
3. Nina bekommt eine Einladung per E-Mail und installiert die App über die TestFlight-App.

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

> CalSync kopiert Termine aus einem Quellkalender in einen Zielkalender, zum Beispiel
> von Outlook nach iCloud. Bitte prüfe:
>
> - Kalenderzugriff erlauben und eine Synchronisierung mit Quelle und Ziel anlegen.
> - Einmal „Alle synchronisieren“ antippen: Werden Termine korrekt kopiert?
> - Einen Termin in der Quelle ändern: Wird die Kopie beim nächsten Sync aktualisiert?
> - Einen Termin in der Quelle löschen: Verschwindet die Kopie?
> - Den privaten Modus testen: Steht in der Kopie nur der Zeitraum mit dem Titel „Beschäftigt“?
> - „URL kopieren“ ausschalten und einen Termin mit Teams-Beitrittslink prüfen: Der Link und die Beitrittstexte sollen aus Notizen und Ort verschwinden, Meeting-ID und Passcode bleiben.
> - Quelle oder Ziel ändern: Fragt CalSync, ob die alten Kopien entfernt werden sollen?
> - „Kopierte Termine entfernen“ ausprobieren.
> - Die App schließen und wieder öffnen: Läuft die Synchronisierung automatisch?
>
> Rückmeldungen gern mit Screenshot und iOS-Version an hakan@erduman.de.
