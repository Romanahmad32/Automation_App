import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';

/// Flex-Gewichte der Spalten. Header und Zeilen teilen sich dieselben Werte,
/// damit die Spalten exakt untereinander stehen und die Tabelle immer die
/// volle Breite fuellt (kein horizontales Scrollen / Abschneiden).
const int flexName = 5;
const int flexFiles = 4;

/// Der Stand der Vorlage (#104 Stufe 4). Schmaler als „Dateien": Er traegt
/// genau ein Kennzeichen, das seinen Text notfalls kuerzt.
const int flexStand = 3;
const int flexFields = 2;

/// Platz fuer die drei Zeilenaktionen (bearbeiten, duplizieren, loeschen).
/// Ein `IconButton` misst 48 px unabhaengig von der Schriftstufe, drei also
/// 144 — der Rest ist Luft zum Spaltenrand. Mit den frueheren 112 px lief die
/// Zeile bei 700 px und groesster Schrift ueber
/// (`vorlagen_tabelle_schmal_test.dart`).
const double actionsWidth = 160;

/// Spaltenindizes fuer die Sortierung. „Stand" haengt hinten an, statt sich an
/// seinen Platz in der Zeile einzureihen: Die Zahlen stehen in gespeicherten
/// Sortierzustaenden nicht, aber ein Umnummerieren waere eine stille Aenderung
/// an zwei Dateien.
const int colName = 0;
const int colFiles = 1;
const int colFields = 2;
const int colStand = 3;

/// Anzahl der hinterlegten Word-Dateien (0–2) — Sortierschluessel der Spalte
/// „Dateien".
int fileCount(FormTemplate t) =>
    (t.hasOhneAuflistung ? 1 : 0) + (t.hasMitAuflistung ? 1 : 0);

/// Sortierschluessel der Spalte „Stand": Was Arbeit macht, steht vorn.
/// Unvollstaendig (0) vor „noch nicht geprueft" (1) vor vollstaendig (2) —
/// aufsteigend sortiert zeigt die Tabelle damit zuerst, was der Anwalt noch
/// anfassen muss.
int standRang(FormTemplate t) {
  final stand = t.stand;
  if (stand == null) return 1;
  return stand.vollstaendig ? 2 : 0;
}
