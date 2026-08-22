# backup — Datensicherung und Wiederherstellung

**Zweck:** Der Anwalt sichert den gesamten Bestand aus der App heraus in eine einzelne Datei und
spielt eine solche Sicherung wieder ein — für ein Backup oder den Umzug auf einen neuen Rechner.
**Anforderung:** `REQUIREMENTS.md` §7.2
**Einstieg:** `presentation/widgets/data_backup_body.dart`
**Zustand:** `BackupCubit` (`presentation/cubit/backup_cubit.dart`) mit den Zuständen
`BackupIdle`/`BackupBusy`/`BackupErfolg`/`BackupFehler` (`presentation/cubit/backup_state.dart`)
**Domain:** keine Entity; nur der Port `BackupRepository`
(`domain/repositories/backup_repository.dart`) mit `exportDatenbank`/`importDatenbank`
**Backend:** `Features/Backup/` · `GET /api/Backup/export`, `POST /api/Backup/import`
**Tests:** —

**Fallstricke**

- Kein eigener Tab: die Ansicht hängt als Reiter „Datensicherung" in
  `features/settings/presentation/pages/settings_page.dart` und bekommt ihren Cubit über
  `presentation/views/data_backup_view.dart`.
- Kein Repository-Impl: `ApiBackupDatasource` setzt `BackupRepository` direkt um
  (`@Injectable(as: BackupRepository)`) — das zweite in CLAUDE.md erlaubte Muster, kein Versehen.
  Der Cubit nennt sein Feld deshalb `_datasource`, obwohl der Typ das Repository ist.
- Der Import überschreibt alle Daten und läuft bewusst erst nach Rückfrage (`_bestaetigeImport`);
  dieser Bestätigungsschritt darf nicht wegautomatisiert werden. Das Backend legt zusätzlich vor dem
  Einspielen eine Kopie des bisherigen Standes an, und die Erfolgsmeldung („App neu starten") kommt
  vom Backend, nicht aus dem Frontend.
- Die Sicherung ist ein **ZIP** aus Datenbank *und* Word-Vorlagen (seit die Vorlagen unter
  `%APPDATA%` liegen). Der Öffnen-Dialog lässt `db`/`bak` weiterhin zu, damit ältere Sicherungen aus
  der Zeit davor einspielbar bleiben — das ist Absicht, kein vergessener Filter.
- Eigene 5-Minuten-Timeouts statt der Dio-Defaults (3 s), sonst brechen große Bestände ab. Das
  Multipart-Feld muss `datei` heißen, sonst bindet der `IFormFile`-Parameter des Controllers nicht.
