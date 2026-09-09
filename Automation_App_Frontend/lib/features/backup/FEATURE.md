# backup — Datensicherung und Arbeitsplatzwechsel

**Zweck:** Lokale Daten sichern und zwischen Büro und Zuhause über einen gemeinsamen Ordner übergeben.
Die Shell prüft alle 15 Sekunden; eine Übernahme ersetzt den Bestand erst nach Bestätigung.
**Anforderung:** `REQUIREMENTS.md` §7.2
**Einstieg:** `presentation/widgets/synchronisations_leiste.dart` (zentrale Prüfung),
`presentation/widgets/arbeitsplatz_uebergabe_gate.dart` (Start), `presentation/widgets/data_backup_body.dart` (Bedienung)
**Zustand:** `BackupCubit` für manuellen Export/Import; `SynchronisationsLeisteState` für Status und Aktionen,
`ArbeitsplatzUebergabeGateState` vor Router und Theme. `DatenstandSignal` lädt nach Import alle Ansichten neu.
**Domain:** `UebergabeStand`, `UebergabeAngebot`, `LetzteSicherung`, `SynchronisationsFehler` (`domain/entities/`);
Port `BackupRepository`: `exportiereNach`/`importiere`, `uebergabeStand`, `uebernehmeStand`, `jetztBereitstellen`.
**Backend:** `Features/Backup/` · `GET|POST /api/Backup/export|import`, `GET /api/Backup/uebergabe`,
`POST /api/Backup/uebergabe/uebernehmen`, `POST /api/Backup/bereitstellen`,
`POST /api/Backup/sicherungsstand/quittieren`. `SicherungsZeitgeber`: 30 Minuten und nur bei Änderung.
**Tests:** `test/features/backup/arbeitsplatz_uebergabe_test.dart`, `sicherungs_stand_zeile_test.dart`,
`synchronisations_leiste_test.dart`; Backend `SynchronisationsVerlaufTests`, `SynchronisationsImportTests`,
`SynchronisationsSchutzTests` und die vorhandenen Sicherungstests.

**Fallstricke** — ausführlich in `FALLSTRICKE.md`.

- „Bereitgestellt“ bestätigt die lokale Ablage, nicht den OneDrive-Upload. Die App verspricht keinen Cloud-Status.
- Neue Stände tragen Revision und Vorgänger. Eine spätere Sicherungszeit macht unveränderte Daten nicht neuer.
- Eine Prüfkennung bindet die Zustimmung an den angezeigten fremden und lokalen Bestand.
- Konflikte brauchen eine ausdrückliche Auswahl; kein Zusammenführen und keine stille Übernahme.
- ZIPs enthalten Datenbank, Vorlagen, erfasste Anhänge und Prüfsummen. Akten liegen separat in OneDrive.
- Import prüft und migriert vor dem Tausch; alte `.db`-/ZIP-Sicherungen bleiben lesbar.
- Relative Einstellungspfade bleiben portabel, absolute Einstellungspfade behalten den lokalen Wert.
- Die featureübergreifende Kette steht in [`docs/DATENFLUESSE.md`](../../../../docs/DATENFLUESSE.md).
- Einrichtung und Alltag: [`Arbeitsplatzwechsel`](../../../../docs/ONEDRIVE_ARBEITSPLATZWECHSEL.md).
