# backup — Datensicherung, Wiederherstellung und Arbeitsplatz-Übergabe

**Zweck:** Der Anwalt sichert den gesamten Bestand aus der App heraus in eine einzelne Datei und
spielt eine solche Sicherung wieder ein. Dazu die **Übergabe** zwischen zwei Arbeitsplätzen: Die App
sichert beim Beenden in einen synchronisierten Ordner, und der zweite Rechner bietet diesen Stand
beim Öffnen zur Übernahme an — nach Rückfrage, nie von selbst.
**Anforderung:** `REQUIREMENTS.md` §7.2
**Einstieg:** `presentation/widgets/data_backup_body.dart` (Reiter),
`presentation/widgets/arbeitsplatz_uebergabe_gate.dart` (Start)
**Zustand:** `BackupCubit` (`presentation/cubit/backup_cubit.dart`) mit
`BackupIdle`/`BackupBusy`/`BackupErfolg`/`BackupFehler` für den Reiter. Die Übergabe hat bewusst
keinen Bloc: Sie ist ein einmaliger Schritt beim Start, vor Router und Theme
(`ArbeitsplatzUebergabeGateState`).
**Domain:** `UebergabeStand`, `UebergabeAngebot`, `LetzteSicherung` (`domain/entities/`); Port
`BackupRepository` mit `exportDatenbank`/`importDatenbank`/`uebergabeStand`/`uebernehmeStand`/
`quittiereSicherungsfehler`
**Backend:** `Features/Backup/` · `GET|POST /api/Backup/export|import`,
`GET /api/Backup/uebergabe`, `POST /api/Backup/uebergabe/uebernehmen`,
`POST /api/Backup/sicherungsstand/quittieren`
**Tests:** `test/features/backup/arbeitsplatz_uebergabe_test.dart`,
`test/features/backup/sicherungs_zeitpunkt_test.dart`

**Fallstricke** — die ausführliche Fassung steht in `FALLSTRICKE.md` daneben.

- Kein eigener Tab: die Ansicht hängt als Reiter „Datensicherung" in
  `features/settings/presentation/pages/settings_page.dart`.
- Kein Repository-Impl: `ApiBackupDatasource` setzt `BackupRepository` direkt um — das zweite in
  CLAUDE.md erlaubte Muster, kein Versehen.
- Import und Übernahme ersetzen alle Daten und laufen erst nach Rückfrage. Dieser Schritt darf nicht
  wegautomatisiert werden.
- Die Kette Beenden → Ablage → Start → Übernahme läuft über mehrere Features und steht in
  [`docs/DATENFLUESSE.md`](../../../../docs/DATENFLUESSE.md).
