/// Deutsches Datum `TT.MM.JJJJ` (z. B. `01.09.2026`).
String deutschesDatum(DateTime wert) =>
    '${wert.day.toString().padLeft(2, '0')}.'
    '${wert.month.toString().padLeft(2, '0')}.'
    '${wert.year.toString().padLeft(4, '0')}';

/// Uhrzeit `HH:MM` (z. B. `14:12`), ohne Sekunden.
String deutscheUhrzeit(DateTime wert) =>
    '${wert.hour.toString().padLeft(2, '0')}:'
    '${wert.minute.toString().padLeft(2, '0')}';

/// Deutsches Datum mit Uhrzeit `TT.MM.JJJJ HH:MM` (z. B. `01.09.2026 14:12`).
String deutschesDatumMitUhrzeit(DateTime wert) =>
    '${deutschesDatum(wert)} ${deutscheUhrzeit(wert)}';

/// ISO-Datum `JJJJ-MM-TT` (z. B. `2026-09-01`), wie es HTTP-Schnittstellen
/// erwarten.
String isoDatum(DateTime wert) =>
    '${wert.year.toString().padLeft(4, '0')}-'
    '${wert.month.toString().padLeft(2, '0')}-'
    '${wert.day.toString().padLeft(2, '0')}';
