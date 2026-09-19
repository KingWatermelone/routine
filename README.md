# Routine

Routine ist ein plattformübergreifender, offline arbeitender persönlicher
Aufgabenplaner für iOS, macOS und Windows. Version 0.1.0 bildet den ersten MVP;
Konten, Cloud-Synchronisierung und weitere Organizer-Module sind bewusst noch
nicht enthalten.

## Funktionsumfang

- Aufgaben erstellen, bearbeiten, abschließen, wieder öffnen und löschen
- Beschreibung, Priorität, Fälligkeit und mehrere Erinnerungszeiten
- benutzerdefinierte Kategorien mit stabiler ID, Name, Farbe und Symbol
- mehrere Tags pro Aufgabe
- Suche in Titel, Beschreibung und Tags
- kombinierbare Filter nach Status, Kategorie, Tag, Priorität und Termin
- Sortierung nach Fälligkeit, Priorität, Kategorie, Status oder Erstellung
- Ansichten für heute, demnächst, überfällig und abgeschlossene Aufgaben
- lokale, versionierte Speicherung und sichere Migration vorhandener Daten
- lokale Betriebssystem-Benachrichtigungen auf iOS, macOS und Windows
- responsive Oberfläche für schmale mobile und breite Desktop-Fenster

## Lokal starten

Voraussetzung ist Flutter 3.47 oder neuer.

```sh
flutter pub get
flutter run
```

Qualitätsprüfungen:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

GitHub Actions führt Formatprüfung, Analyse und Tests unter Linux sowie einen
Windows-Debug-Build für jeden Pull Request und jeden `codex/**`-Branch aus.

## Kategorien und Datenmigration

Die Ordner-Schaltfläche in der Aufgabenansicht öffnet die Kategorieverwaltung.
Kategorien können erstellt, umbenannt, umgefärbt, mit einem anderen Symbol
versehen und gelöscht werden. Aufgaben speichern die Kategorie-ID statt des
Namens. Eine Umbenennung ändert deshalb keine Zuordnung. Beim Löschen bleiben
die Aufgaben erhalten und werden „Ohne Kategorie“ zugeordnet.

Beim ersten Start migriert Routine den bisherigen Schlüssel
`routine.tasks.v1` in den versionierten Datensatz `routine.organizer.v2`.
Nichtstandardmäßige ältere Kategorien werden übernommen, äquivalente Namen
zusammengeführt und die ursprünglichen v1-Daten als unveränderte Sicherung
behalten. Eine fehlgeschlagene oder unbekannte Speicherung wird sichtbar
gemeldet und nicht mit Standarddaten überschrieben.

Routine speichert derzeit mit SharedPreferences ausschließlich lokal. Das ist
keine Cloud-Sicherung und keine Synchronisation zwischen Geräten.

## Erinnerungen

Nach einem erfolgreichen Speichern gleicht Routine alle zukünftigen
Erinnerungen offener Aufgaben mit dem Betriebssystem ab. Bearbeiten, Abschließen
oder Löschen storniert veraltete, noch ausstehende Erinnerungen. Vergangene
Zeitpunkte werden nicht nachträglich ausgelöst. Bei einem Neustart oder beim
Zurückkehren in die App wird der gespeicherte Zustand erneut abgeglichen.

Routine plant höchstens die nächsten 64 Erinnerungen. Weitere Zeiten bleiben
gespeichert und werden sichtbar gemeldet. Die Zustellung hängt weiterhin von
den Berechtigungs-, Fokus- und Benachrichtigungseinstellungen des Systems ab.

- iOS und macOS verwenden UserNotifications über einen Flutter-MethodChannel.
- Windows verwendet `flutter_local_notifications_windows` und reserviert für
  Aufgaben IDs von `0x40000000` bis `0x7fffffff`.
- iOS fragt erst beim Speichern einer zukünftigen Erinnerung nach Erlaubnis.
- Windows besitzt keinen entsprechenden App-Dialog; Routine prüft dort die
  Systemeinstellung und bietet bei deaktivierten Benachrichtigungen einen Link
  zu den Einstellungen an.

Apple-Referenzen: [lokale Benachrichtigungen planen](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app),
[Berechtigung anfragen](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
und [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels).

## Plattform-Builds

### iOS

Öffne `ios/Runner.xcworkspace` in Xcode, wähle dein Entwicklungsteam und baue
Runner für ein iPhone. Die Bundle-ID ist `com.kingwatermelone.routine`. Lokale
Benachrichtigungen benötigen weder Push-Notification-Entitlement noch einen
Hintergrundmodus.

### macOS

```sh
flutter run -d macos
flutter build macos --release
```

Native Tests liegen im Xcode-Ziel `RunnerTests` von
`macos/Runner.xcworkspace`.

### Windows

Benötigt Visual Studio 2022 mit **Desktop development with C++**.

```powershell
flutter run -d windows
flutter build windows --release
```

Für ein lokal installierbares MSIX ist `msix_config` vorbereitet:

```powershell
dart pub global activate msix 3.18.0
dart pub global run msix:create
```

Ein öffentlich verteiltes MSIX muss mit einem vertrauenswürdigen Zertifikat
signiert oder über den Microsoft Store veröffentlicht werden. Private
Signaturschlüssel gehören nicht in das Repository.

## Release-Unterlagen

- [vollständige Release- und manuelle Abnahmeliste](docs/release-checklist.md)
- [Datenschutzhinweise](PRIVACY.md)
- [Changelog](CHANGELOG.md)

Die Release-Liste umfasst insbesondere echte Benachrichtigungszustellung bei
geöffneter und geschlossener App, Bestandsmigration, schmale und breite Layouts
sowie plattformspezifische Signierung. Ein Pull Request wird nicht automatisch
gemergt.
