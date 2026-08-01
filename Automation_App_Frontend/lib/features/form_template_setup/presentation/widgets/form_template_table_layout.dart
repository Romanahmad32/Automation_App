import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';

/// Flex-Gewichte der Spalten. Header und Zeilen teilen sich dieselben Werte,
/// damit die Spalten exakt untereinander stehen und die Tabelle immer die
/// volle Breite fuellt (kein horizontales Scrollen / Abschneiden).
const int flexName = 5;
const int flexFiles = 4;
const int flexFields = 2;
const double actionsWidth = 112;

/// Spaltenindizes fuer die Sortierung.
const int colName = 0;
const int colFiles = 1;
const int colFields = 2;

/// Anzahl der hinterlegten Word-Dateien (0–2) — Sortierschluessel der Spalte
/// „Dateien".
int fileCount(FormTemplate t) =>
    (t.hasOhneAuflistung ? 1 : 0) + (t.hasMitAuflistung ? 1 : 0);
