# Automation_App

Windows-Desktop-App für die Verkehrsunfall-Mandate einer Einzelkanzlei:
Zentralruf-Anfrage → Antwort auswerten → Anspruchsschreiben (inkl.
RVG-Berechnung) erzeugen → prüfen, ablegen, versenden.

Das verbindliche Anforderungsdokument (`REQUIREMENTS.md`) und die
Arbeitsanweisungen für AI-Agents (`CLAUDE.md`) beschreiben interne
Kanzleiabläufe und sind deshalb nicht Teil dieses öffentlichen Repos;
sie liegen nur lokal im Arbeitsverzeichnis.

## Struktur

Monorepo. Frontend, Backend und die übergreifenden Dokumente liegen in einem
Repo, damit eine Änderung am API-Vertrag als **ein** Commit und **ein** Diff
reviewbar ist — Flutter-Entity und C#-DTO sind nur über String-Keys verbunden,
ein Umbenennen auf einer Seite bricht die andere still zur Laufzeit.

```
Automation_App/
├── AutomationService/          ASP.NET-Core-Backend (net10.0), Port 5143
├── Automation_App_Frontend/    Flutter-Desktop-Frontend (Ziel: Windows)
├── Beispiele/                  Anonymisierte Testdaten + Word-Vorlagen
├── docs/                       OUTLOOK_SETUP.md (Azure-App-Registrierung)
└── tools/                      Eigenständige .NET-Hilfsprogramme
```

Beide Unterprojekte behalten ihre eigene `.gitignore`; die an der Wurzel
enthält nur repoweite Regeln.

## Entwickeln

```powershell
# Backend
cd AutomationService/AutomationService
dotnet run                                  # http://localhost:5143
dotnet test AutomationService.Tests

# Frontend
cd Automation_App_Frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter test                                # inkl. Architektur-Tests
flutter analyze
```

Dateien auf `.g.dart`, `.freezed.dart`, `.gr.dart` und `injection.config.dart`
sind generiert — nie von Hand ändern, stattdessen build_runner laufen lassen.

## Historie

Dieses Repo hieß vormals `flutter_automation_app`. Backend und Frontend waren
getrennte Repos; das Backend ist per Subtree-Merge eingegliedert. Beide
Historien sind vollständig erhalten:

```bash
git log -- AutomationService/          # Backend-Linie
git log --follow -- Automation_App_Frontend/lib/main.dart   # Frontend-Linie
```

## Datenschutz

Es gehören **keine** echten Mandantendaten ins Repo (DSGVO, § 203 StGB).
`Beispiele/Anwortemail von Zentralruf.txt` ist eine **anonymisierte** Fassung
einer echten Zentralruf-Antwort: Kennzeichen, Versicherungsschein-Nummer und
Kanzleiblock sind durch Platzhalter ersetzt, Struktur und Formatierung sind
unverändert, damit der Parser realistisch getestet wird. Generierte Schreiben
(`Generated/`), die SQLite-DB und Aktenordner sind per `.gitignore`
ausgeschlossen.
