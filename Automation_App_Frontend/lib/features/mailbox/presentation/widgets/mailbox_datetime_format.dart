import 'package:automation_app/core/general_classes/datum_format.dart';

/// Einheitliche Datums-/Zeitanzeige der Postfach-Ansicht (TT.MM.JJJJ HH:MM).
String formatMailboxDateTime(DateTime value) => deutschesDatumMitUhrzeit(value);
