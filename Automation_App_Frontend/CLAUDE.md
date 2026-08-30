# CLAUDE.md — Flutter-Frontend

Gilt für `Automation_App_Frontend/`. Projektzweck, Repository-Layout, Backend, HTTP-Vertrag,
Release und CI stehen in der Wurzel-`CLAUDE.md`.

## Befehle (aus `Automation_App_Frontend/`)

```powershell
flutter pub get
dart run build_runner build   # nach Änderungen an DI, Routen, freezed- oder json-Klassen
flutter run -d windows
flutter test
flutter analyze

flutter test test/features/versicherer/versicherer_cubit_test.dart   # eine Datei
flutter test --plain-name "findet den Eintrag"                       # ein Test, überall
```

Während der Arbeit **einzeln** testen: Die volle Suite braucht rund 30 s, eine Datei unter 2 s.
Steht das projektlokale FVM-SDK bereit (`docs/RELEASE.md`), `fvm flutter …` bzw. `fvm dart …`
verwenden — sonst läuft der Befehl mit dem Flutter aus dem PATH, das von der Pinnung abweichen darf.

Dateien auf `.g.dart`, `.freezed.dart`, `.gr.dart`, `.config.dart` und `.mocks.dart` sind generiert —
**nie von Hand ändern**, stattdessen build_runner laufen lassen. Versioniert sind davon nur
`lib/core/di/injection.config.dart` und `lib/core/router/app_router.gr.dart`; ändert sich eine davon,
gehört sie in denselben Commit wie die Annotation, die sie ausgelöst hat.

Beim Entwickeln das Backend (`dotnet run`) **vor** `flutter run -d windows` starten: ein Debug-Build
hat keinen gebündelten Dienst neben sich und zeigt sonst den Startfehler-Bildschirm statt der
Oberfläche — dessen „Erneut versuchen"-Knopf spart den Flutter-Neustart. `flutter test` aus dem
Paket-Stammverzeichnis aufrufen, sonst brechen die Architektur-Tests mit einem Hinweis ab.

## Aufbau: Clean Architecture je Feature

Jedes Feature unter `lib/features/<feature>/` gliedert sich in `data/` (Datasources,
Repository-Umsetzungen) → `domain/` (Entities, Repository-Schnittstellen, UseCases) ←
`presentation/` (Blocs, Pages, Views, Widgets). Erlaubte Richtung: `presentation ──▶ domain ◀── data`.
`domain` ist die innerste Schicht: keine Abhängigkeit auf `data`/`presentation` und frei von
Flutter-UI; `data` kennt `presentation` nicht, und `presentation` greift nicht an der Domain vorbei
auf `data` zu. Genau diese vier Regeln prüft `clean_architecture_test.dart`.

Über Featuregrenzen hinweg wird die `presentation`-Schicht dagegen geteilt: eine Seite bindet Blocs
fremder Features ein (`word_automation_page.dart` nutzt `AblageCubit` aus `mandanten`,
`KanzleiSettingsBloc` aus `settings`, `VorgangCubit` aus `vorgaenge`). Das ist gängige Praxis im
Bestand und wird von **keinem** Test aufgehalten — verlass dich nicht darauf, dass ein Feature für
sich steht.

Bibliotheken: Zustand über **flutter_bloc**, DI über **get_it + injectable** (Annotationen +
generierte Konfiguration), Navigation über **auto_route** (Routen in
`lib/core/router/app_router.dart`), Formulare über **reactive_forms**, HTTP über **dio**.

Querschnittliches unter `lib/core/`: `router`, `di`, `network`, `theme`, `backend` (Dienststart,
`BackendEndpoint`), `aktualisierung` (Versionsprüfung), `general_classes`
(Failures/Exceptions/UseCase-Basis), `general_widgets`.

**Keine lokale Persistenz im Frontend**: jeder Bestand läuft über HTTP gegen das Backend und landet
dort in SQLite. Die früheren JSON-Speicher (`kanzlei_settings.json`, `mandanten.json`, …) gibt es
nicht mehr.

### Features

Jedes Feature hat einen **Steckbrief** `lib/features/<feature>/FEATURE.md` — Zweck, Einstiegsdatei,
Blocs, Domain-Typen, Backend-Slice mit Endpunkten, Tests und Fallstricke. **Vor der Arbeit an einem
Feature zuerst den Steckbrief lesen**, er erspart das Absuchen des Ordners. Alle Steckbriefe tragen
dieselben Feldnamen, `grep -h "Backend:" lib/features/*/FEATURE.md` beantwortet also
featureübergreifende Fragen in einem Zugriff.

**Was über den Feature-Rand hinausgeht, steht in [`docs/DATENFLUESSE.md`](../docs/DATENFLUESSE.md)**:
vier Ketten laufen quer durch mehrere Features (Vorbelegung, Antwortübernahme, Abschluss,
Kanzleidaten), und der Steckbrief eines einzelnen Features sagt nicht, dass es Teil einer ist. Wer
eine Kette an einer Stelle ändert und die andere stehen lässt, bricht sie — kein Test fängt das.

Der Steckbrief hat ein Budget (40 Zeilen, keine über 130 Zeichen) — es hält ihn zum Einstieg
tauglich. Wo mehr zu erklären ist, liegt daneben eine **`FALLSTRICKE.md` ohne Budget** (welche
Features eine haben, sagt `ls lib/features/*/FALLSTRICKE.md` — eine Aufzählung hier veraltet
stillschweigend); der Steckbrief verweist darauf, ein Test besteht darauf.
Was nicht mehr in die vierzig Zeilen passt, wandert **dorthin** — nie in kürzere Sätze: Absätze
zusammenzuziehen, um unter das Budget zu kommen, hat schon einmal lesbare Doku unlesbar gemacht.

| Feature | wofür |
|---|---|
| `dashboard` | Startseite: offene Vorgänge, unbearbeitete Antworten, letzte Registerzeilen — lesend |
| `vorgang_starten` | Mandatsdaten erfassen, Zentralruf-Anfrage anstoßen, legt den `Vorgang` an |
| `zentralruf_request` | Vorbefüllung des Zentralruf-Onlineformulars |
| `zentralruf_reply` | Antwortmail auswerten und in einen Vorgang übernehmen |
| `mailbox` | Status und Posteingang des Postfachs — **und** die Zugangsmaske in den Einstellungen |
| `word_automation` | Assistent füllen → (Schadensaufstellung) → prüfen → speichern, versenden, schließt den Vorgang ab |
| `email_versand` | Mail zum Vorgang verfassen: senden oder als Entwurf in Outlook öffnen; Signatur-Import |
| `form_template_setup` | Feldbeschreibungen zu einer Word-Vorlage |
| `mandanten` | Mandantenregister (Datenbank) + Akten/Fälle (Dateisystem) |
| `versicherer` | lesender Zugriff auf die Versicherer-Wissensbasis; benutzt aus `zentralruf_reply` |
| `vorgaenge` | Lebenszyklus der Vorgänge + Sachgebiete-/Auftragsregister |
| `settings` | Kanzleidaten, Aktenstammordner, Auftragsnummer/Abteilung, Mail-Signatur, Erscheinungsbild; hängt die Reiter aus `mailbox` und `backup` ein |
| `backup` | Sicherung und Wiederherstellung; aufgerufen aus den Einstellungen |
| `dev_simulation` | Demo-Vorgang + Simulationsmenü, nur in `kDebugMode` sichtbar |

### Navigation

Linke **Sidebar** (`AppSidebar`/`AppShellPage`), Reihenfolge: 0 Übersicht, 1 Vorgang starten,
2 Postfach, 3 Word Automation, 4 Vorlagen Verwalten, 5 Mandanten, 6 Register, 7 Vorgänge,
8 Einstellungen. Die Indizes stehen zentral in `lib/core/router/app_tab_index.dart` (`AppTabIndex`)
und sind beim Umsortieren dort mitzupflegen — Sprünge (`AutoTabsRouter.setActiveIndex`) verwenden
diese Konstanten statt harter Zahlen. **Index 0 ist zugleich der Start-Tab**: was dort steht, sieht
der Anwalt direkt nach dem Öffnen der App.

## Code-Qualität (verbindlich)

- **Dateien kurz halten.** Handgeschriebene Dart-Dateien max. **250 Anweisungszeilen** und **450
  Zeilen insgesamt**. Kommentare und Leerzeilen zählen nicht mit — eine Datei aufzuteilen, um
  Kommentar unterzubringen, wäre ein Schnitt aus der Zählung statt aus dem Entwurf. Wird eine Datei
  länger, in mehrere Widgets/Klassen aufteilen. Zwei Formularseiten liegen noch darüber und stehen
  namentlich in `file_length_test.dart`; sie dürfen nur noch schrumpfen.
- **Keine privaten Typen und keine privaten Top-Level-Funktionen** (kein `_WidgetXyz`, kein
  `_hilfsfunktion()`). Ein privates Widget ist außerhalb seiner Datei kein benennbarer Typ mehr:
  nicht wiederverwendbar, nicht einzeln testbar — und die nächste Änderung baut daneben eine zweite
  Fassung davon. Einzige Ausnahme: die `State`-Klasse eines `StatefulWidget`.
- **Widgets wiederverwendbar gestalten.** Projektweit Genutztes unter `lib/core/general_widgets/`,
  Feature-Eigenes unter `lib/features/<feature>/presentation/widgets/` — je Widget eine Datei.
- **Formular aus einem Bloc füllen: `StandNachziehen`, nie ein blosser Listener.** Ein
  `BlocListener` hört **Übergänge** — den Zustand, auf dem der Bloc beim Mounten schon steht,
  sieht er nie. Das Formular zeigt dann seine Vorgabewerte und sieht aus wie geladen; wer
  „Speichern" drückt, schreibt sie über die echten Daten. Dreimal passiert (Signatur,
  Postfach-Zugang, Kanzleidaten), zweimal in der Kanzlei aufgefallen statt in der Prüfkette.
  `core/general_widgets/stand_nachziehen.dart` trennt `nachziehen` (beim Aufgehen **und** bei
  jedem Zustand) von `beiUebergang` (nur Meldungen). Dazu je ein Widget-Test nach dem Muster
  „war der Bloc schon geladen" — `test/features/mailbox/mailbox_zugang_anzeige_test.dart`.
- **Vorhandene Widgets bevorzugen.** Vor dem Neubau prüfen, ob es schon eins gibt, und dieses
  verwenden bzw. erweitern statt zu duplizieren.
- **Datasources: Sache im Dateinamen, Technik im Klassennamen.** Datei `<sache>_datasource.dart` —
  kein `api_`, `remote_`, `local_` (geprüft werden die Marken `api`, `rest`, `http`, `dio`,
  `remote`, `local`, `db`, `sqlite`, `filesystem`, `memory`). Die Schnittstelle heißt
  `<Sache>Datasource` und trägt keine Technik; die Umsetzung nennt ihre Herkunft als Präfix:
  `Api…` für den HTTP-Zugriff auf das Backend, `Local…`/`Filesystem…`/`InMemory…` für alles andere.
  Kein `Impl`-Suffix. So ist der Pfad aus dem Fachbegriff ableitbar, und eine Suche nach `Api`
  findet jede Stelle, die den Dienst anspricht.
- **Repository-Umsetzungen heißen `<Sache>RepositoryImpl`** (Datei `<sache>_repository_impl.dart`)
  — hier kein `Api…`: diese Schicht spricht kein HTTP, sie ruft die Datasource und übersetzt in
  Domain-Typen und `Failure`s. Braucht ein Feature diese Übersetzung nicht, entfällt die Schicht
  ganz und die Datasource setzt das Repository direkt um (`@Injectable(as: VorgangRepository)`).
  Beides ist erlaubt — nur nicht dieselbe Rolle unter zwei Namen.

### Erzwungen von (Dart-Seite)

| Regel | Test |
|---|---|
| Dateilänge ≤ 250 Anweisungszeilen, ≤ 450 gesamt | `test/architecture/file_length_test.dart` |
| Keine privaten Typen/Top-Level-Funktionen | `test/architecture/private_typen_test.dart` |
| Benennung Datasources/Repositories | `test/architecture/benennung_test.dart` |
| Schichten `domain`/`data`/`presentation` (vier Regeln) | `test/architecture/clean_architecture_test.dart` |
| HTTP-Vertrag gegen `docs/openapi.json` (Wurzel-`CLAUDE.md`) | `test/architecture/http_vertrag_test.dart` |
| Steckbrief je Feature, Feature-Tabelle, Zeilenbudget der `CLAUDE.md`, lebende Verweise | `test/architecture/dokumentation_test.dart` |
| Anforderungsverweise (`§4.8`, nie `Req. …`) gegen den Index, Index gegen `REQUIREMENTS.md` | `test/architecture/anforderungen_test.dart` |
| Formatierung | `dart format --set-exit-if-changed` (CI) |

Generierte Dateien sind überall ausgenommen (`test/architecture/dart_source_files.dart`).
Schlägt eine dieser Prüfungen fehl, ist die Antwort **nie**, die Regel zu lockern oder das Limit
hochzusetzen — begründete Ausnahmen gehören namentlich in den jeweiligen Test.

## Vorhandene Bausteine (`lib/core/general_widgets/`)

- `form/` — `GeneralTextField`, `GermanDateField`, `FormSection`, `FormWertBeobachter`
- `buttons/` — `CustomRectangularButton`; `buttons/dropdowns/` — `SearchableDropdown`
  (+ `SearchableDropdownEntry`), `ReactiveSearchableDropdown`, `TemplateSelector`
- `drawer/` — `AppShellPage`, `AppSidebar`, `SidebarItem`, `SidebarFooter`, `SidebarThemeToggle`,
  `SidebarUpdateHinweis`
- `page_refresh/` — `PageRefreshScope`, `PageRefreshButton`, `PageRefreshController`,
  `PageRefreshInherited`
- direkt darunter — `SeitenAppBar`, `EntitySearchBar`, `FehlerHinweis`, `AnwendungsInfo`,
  `UeberAnwendungDialog`, `UpdateHerunterladenButton`, `VersionBadge`, `DateiAblageBereich`
  (nimmt aus dem Explorer gezogene Dateien entgegen, `desktop_drop`)
