# mandanten — Mandantenregister und Aktenablage

**Zweck:** Stammdaten der Mandanten pflegen und je Mandant die Akten und Fälle sehen, die im
Dateisystem zu ihm gehören. Grundlage für Wiederverwendung der Daten, Aktenablage und Parteienbezeichnung.
**Anforderung:** `REQUIREMENTS.md` §5.1, §6.1, §4.6
**Einstieg:** `data/repositories/mandanten_repository_impl.dart`
**Zustand:** `presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart`,
`presentation/blocs/mandant_edit_cubit/mandant_edit_cubit.dart`,
`presentation/blocs/ablage_cubit/ablage_cubit.dart`,
`presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart`
**Domain:** `Mandant`, `Akte`, `Fall`, `Aktentyp`, `OrdnerStatus`, `Anrede`, `CreateMandantRequest`,
`MandantenImportDatei`, `ImportBericht`, `MandantErkennung`, `AktentypErkennung`, `AblageErgebnis`,
`AblageStrategie`; `GetMandanten`, `CreateMandant`, `UpdateMandant`, `DeleteMandant`, `GetAkten`,
`GetFaelle`, `GetOrdnerStatus`, `SetzeOrdnerStatus`, `LiesImportDatei`, `ImportiereMandanten`,
`VerknuepfeOrdnerMitMandant`, `LegeDokumentAb`
**Backend:** `Features/Mandanten/` · `GET/POST /api/Mandanten`, `PUT/DELETE /api/Mandanten/{id}`,
`GET/PUT /api/OrdnerStatus`, `POST /api/MandantenImport` (Format: `docs/MANDANTEN_IMPORT.md`) —
Akten und Fälle laufen über keinen Endpunkt, sie kommen direkt aus dem Dateisystem.
**Tests:** `test/features/mandanten/`, Einstieg `test/features/mandanten/mandanten_overview_bloc_test.dart`,
`test/features/mandanten/mandanten_import_cubit_test.dart`,
`test/features/mandanten/akten_datasource_test.dart`

**Fallstricke**

- Der lange Rest steht in `FALLSTRICKE.md` daneben: Zuordnungsstapel, Import, Ablage, Register.
- Zwei Herkünfte in einem Feature: `ApiMandantDatasource` und `ApiOrdnerStatusDatasource` holen
  Register und Vermerke per HTTP aus der Backend-Datenbank, `FilesystemAktenDatasource` scannt den
  Stammordner mit `dart:io`. Akten und Fälle sind reine Laufzeitsicht.
- **Der Akten-Scan ist flach.** `getAkten()` liefert die Ordner ohne ihre Fälle, die holt `GetFaelle`
  je Akte nach (`Akte.faelleGeladen`). Im Produktivbestand liegen rund 4000 Ordner unter dem
  Stammordner — sie mit ihren Fällen und Dateien zu lesen dauert auf dem Netzlaufwerk Minuten.
- **Ein Ordner hat drei Zustände**, nicht zwei: zugeordnet (steht am Mandanten), offen, oder
  „ohne Mandantenbezug" (`OrdnerStatus`). `ZuordnungFilter.ansichtVon` teilt danach auf.
- **Der Import schreibt erst nach Freigabe.** `POST /api/MandantenImport` ohne `uebernehmen` prüft nur;
  Vorschau und Übernahme sind derselbe Aufruf. In der Vorschau ist jede Zeile noch änderbar.
- Verknüpfung **und** Vermerk hängen am **Ordnernamen**, nicht am Pfad. Ein im Explorer umbenannter
  Ordner erscheint deshalb wieder als offen, und der Eintrag am Mandanten zeigt ins Leere.
- Fehlt der Stammordner, liefert `getAkten()` eine leere Liste statt eines Fehlers, und
  `MandantenOverviewBloc` verwirft ein `Left` des Scans still — leer ist Absicht, kein Fehlerschlucken.
