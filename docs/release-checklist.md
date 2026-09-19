# Release- und Abnahmeliste für Routine 0.1.0

Diese Liste ist der letzte manuelle Schritt vor einer Veröffentlichung. Hake sie
auf den tatsächlich unterstützten Zielgeräten ab. CI ersetzt insbesondere keine
Prüfung der Benachrichtigungszustellung.

## 1. Gemeinsame Prüfungen

Auf jeder Entwicklungsmaschine:

```sh
flutter clean
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

- [ ] Alle Befehle enden ohne Fehler oder Warnungen.
- [ ] Eine neue Aufgabe lässt sich nur mit einem Titel anlegen.
- [ ] Titel, Beschreibung, Priorität, Fälligkeit und mehrere Erinnerungen lassen
      sich bearbeiten und bleiben nach einem Neustart erhalten.
- [ ] Abschließen, Wiederöffnen und endgültiges Löschen funktionieren.
- [ ] Ein leerer Titel und eine Erinnerung nach der Fälligkeit zeigen eine
      verständliche Fehlermeldung.
- [ ] Suche findet Titel, Beschreibung und Tags.
- [ ] Status-, Kategorie-, Tag-, Prioritäts- und Terminfilter lassen sich
      kombinieren.
- [ ] Jede angebotene Sortierung liefert eine stabile, nachvollziehbare Reihenfolge.

## 2. Kategorien und Tags

- [ ] Kategorie mit Name, Farbe und Symbol erstellen und einer Aufgabe zuweisen.
- [ ] Umbenennen sowie Farbe/Symbol ändern; die Aufgabe bleibt zugeordnet und
      Liste, Filter und Editor aktualisieren sich sofort.
- [ ] Leere sowie doppelte Namen testen, auch mit anderer Großschreibung und
      Leerzeichen am Rand.
- [ ] Eine verwendete Kategorie löschen; der Hinweis erscheint, die Aufgabe
      bleibt erhalten und steht anschließend unter „Ohne Kategorie“.
- [ ] Kategorien und Zuordnungen bleiben nach dem Neustart erhalten.
- [ ] Tags anlegen und entfernen; doppelte Tags mit anderer Großschreibung werden
      verhindert.
- [ ] Die Abläufe bei 320 px Fensterbreite und in einem breiten Desktop-Fenster
      ohne abgeschnittene oder unbedienbare Elemente prüfen.

## 3. Bestandsdaten und Offlinebetrieb

- [ ] Vor dem Update mit der vorherigen Version mehrere Aufgaben sowie eine nicht
      standardmäßige Kategorie speichern.
- [ ] Auf 0.1.0 aktualisieren und prüfen, dass Inhalte und Zuordnungen erhalten sind.
- [ ] App zweimal neu starten; die Migration wird nicht erneut ausgeführt.
- [ ] Netzwerk deaktivieren; Erstellen, Bearbeiten, Filtern und Neustarten bleiben
      vollständig funktionsfähig.

## 4. iOS (echtes iPhone)

- [ ] In Xcode `ios/Runner.xcworkspace` öffnen, Entwicklungsteam auswählen und
      `com.kingwatermelone.routine` für das eigene Team registrieren.
- [ ] Runner auf einem iPhone installieren und die gemeinsamen Prüfungen ausführen.
- [ ] Eine Erinnerung bei geöffneter App und eine bei geschlossener App empfangen.
- [ ] Titel/Zeit ändern; die alte Erinnerung darf nicht mehr erscheinen.
- [ ] Aufgabe abschließen und eine andere löschen; ausstehende Erinnerungen werden
      jeweils storniert.
- [ ] Berechtigung zunächst ablehnen, Erklärung und Einstellungen-Schaltfläche
      prüfen, dann aktivieren und erfolgreich erneut planen.
- [ ] Xcode-Testziel `RunnerTests` ausführen.
- [ ] Release-Archiv unter Product → Archive erzeugen und Signierung prüfen.

## 5. macOS

- [ ] `flutter run -d macos` und anschließend `flutter build macos --release` laufen
      ohne Fehler.
- [ ] Vordergrund- und Hintergrundzustellung, Berechtigungsfehler, Bearbeitung,
      Abschluss und Löschung wie unter iOS prüfen.
- [ ] `macos/Runner.xcworkspace` öffnen und `RunnerTests` ausführen.
- [ ] Signiertes Release-Archiv mit dem eigenen Apple-Team erzeugen.

## 6. Windows 10/11

- [ ] `flutter run -d windows` und `flutter build windows --release` laufen ohne
      Fehler.
- [ ] Benachrichtigungen bei geöffneter und geschlossener App sowie Stornierung
      nach Bearbeitung, Abschluss und Löschung prüfen.
- [ ] Deaktivierte Systembenachrichtigungen erzeugen den erklärenden Hinweis und
      die Einstellungen-Schaltfläche öffnet die richtige Seite.
- [ ] Für einen lokalen MSIX-Test einmalig `dart pub global activate msix 3.18.0`
      und danach `dart pub global run msix:create` ausführen.
- [ ] Das erzeugte Testzertifikat bewusst in „Vertrauenswürdige Personen“ des
      lokalen Benutzers importieren, danach `routine-0.1.0-windows.msix`
      installieren und Benachrichtigungen erneut testen. Das Testzertifikat nach
      Abschluss wieder entfernen. Für eine öffentliche Verteilung ein
      vertrauenswürdiges Zertifikat oder den Microsoft Store verwenden; das
      Repository enthält absichtlich keine privaten Schlüssel.

## 7. Veröffentlichung

- [ ] App-Name, Version 0.1.0+1, Icons und Screenshots kontrollieren.
- [ ] [Datenschutzhinweise](../PRIVACY.md) und [Changelog](../CHANGELOG.md) prüfen.
- [ ] Alle CI-Jobs des endgültigen PRs sind grün.
- [ ] Erst nach Abschluss dieser Liste den PR mergen und `v0.1.0` taggen.
- [ ] Signierte Artefakte bzw. Store-Einträge aus dem gemergten Commit erstellen.
