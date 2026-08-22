# mandanten — Mandantenregister und Aktenablage

**Zweck:** Stammdaten der Mandanten pflegen und je Mandant die Akten und Fälle sehen, die im
Dateisystem zu ihm gehören. Grundlage für Wiederverwendung der Daten, Aktenablage und Parteienbezeichnung.
**Anforderung:** `REQUIREMENTS.md` §5.1, §6.1, §4.6
**Einstieg:** `data/repositories/mandanten_repository_impl.dart`
**Zustand:** `presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart`,
`presentation/blocs/mandant_edit_cubit/mandant_edit_cubit.dart`,
`presentation/blocs/ablage_cubit/ablage_cubit.dart`
**Domain:** `Mandant`, `Akte`, `Fall`, `Anrede`, `CreateMandantRequest`, `MandantErkennung`,
`AblageErgebnis`, `AblageStrategie`; `GetMandanten`, `CreateMandant`, `UpdateMandant`, `DeleteMandant`,
`GetAkten`, `VerknuepfeOrdnerMitMandant`, `LegeDokumentAb`
**Backend:** `Features/Mandanten/` · `GET /api/Mandanten`, `POST /api/Mandanten`,
`PUT /api/Mandanten/{id}`, `DELETE /api/Mandanten/{id}` — Akten und Fälle laufen über keinen
Endpunkt, sie kommen direkt aus dem Dateisystem.
**Tests:** `test/features/mandanten/akten_datasource_test.dart`,
`test/features/mandanten/mandant_erkennung_test.dart`

**Fallstricke**

- Zwei Herkünfte in einem Feature: `ApiMandantDatasource` holt das Register per HTTP aus der
  Backend-Datenbank, `FilesystemAktenDatasource` scannt mit `dart:io` den Aktenstammordner aus den
  Einstellungen. Akten und Fälle sind eine reine Laufzeitsicht und werden nirgends persistiert.
- Verknüpft wird über den **Ordnernamen**, nicht über den Pfad (`Mandant.aktenOrdnernamen`). Ein im
  Explorer umbenannter Ordner erscheint deshalb wieder unter „Nicht zugeordnete Ordner“, und der
  Eintrag am Mandanten zeigt ins Leere.
- Fehlt der Stammordner, liefert `getAkten()` eine leere Liste statt eines Fehlers, und
  `MandantenOverviewBloc` verwirft ein `Left` des Scans still — leer ist Absicht, kein Fehlerschlucken.
- `legeDokumentAb` schreibt an zwei Stellen: erst die Dateikopie ins Dateisystem, danach
  `PUT /api/Mandanten/{id}` für den Ordner am Mandanten (nur wenn wirklich abgelegt wurde). Wer an
  der Ablage arbeitet, muss beide Seiten zusammenhalten.
- Die Ablage-Oberfläche liegt nicht hier, sondern in `word_automation`
  (`akten_ablage_section.dart`) — hier liegen nur `AblageCubit` und UseCase; auch der Name des
  Fall-Unterordners entsteht dort.
- Liegt im Fall-Ordner schon eine gleichnamige Datei, **schreibt die Ablage nicht**, sondern meldet
  `AblageErgebnis.konfliktMit` → `AblageStatus.konflikt`; der Cubit merkt sich die offene Anfrage, die
  Oberfläche fragt und ruft `konfliktLoesen(strategie)`. Sonst ersetzt `File.copy` die Akte still.
- Gleicher Vor- und Nachname ergibt beim Anlegen/Ändern ein 409 des Backends, das als
  `MandantException` ankommt. `MandantErkennung` bleibt davon unabhängig reiner Vorschlag — die
  Übernahme ist ein bewusster Klick.
