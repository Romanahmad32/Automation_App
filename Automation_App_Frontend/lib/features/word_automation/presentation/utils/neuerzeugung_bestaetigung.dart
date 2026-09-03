import 'dart:io';

import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:flutter/material.dart';

/// Ob neu erzeugt werden darf, ohne dass dabei stillschweigend Handarbeit
/// verlorengeht.
///
/// Im Prüfschritt kann der Anwalt das Dokument „In Word öffnen" und dort
/// nachbessern (§4.5). Erzeugt er danach neu, überschreibt das seine
/// Änderungen — seit die Erzeugung dieselbe Datei wiederverwendet, statt eine
/// „(2)" danebenzulegen. Ist Word noch offen, meldet das Backend die gesperrte
/// Datei; ist es geschlossen, merkt es sonst niemand.
///
/// Erkannt wird das an der Änderungszeit: liegt sie nach der Erzeugung, hat
/// jemand die Datei angefasst. Rückgabe true = weitermachen.
Future<bool> darfNeuErzeugen(
  BuildContext context,
  EditedDocumentState zustand,
) async {
  if (zustand is! EditedDocumentLoaded) return true;
  final erzeugtAm = zustand.erzeugtAm;
  if (erzeugtAm == null) return true;

  final datei = File(zustand.path);
  if (!datei.existsSync()) return true;
  // Eine Sekunde Luft: Dateisysteme runden die Änderungszeit.
  if (!datei.lastModifiedSync().isAfter(
    erzeugtAm.add(const Duration(seconds: 1)),
  )) {
    return true;
  }

  return bestaetigen(
    context,
    icon: Icons.edit_note,
    titel: 'In Word geänderte Fassung verwerfen?',
    text:
        'Das Dokument wurde nach der Erzeugung geändert — vermutlich von Ihnen '
        'in Word. Neu erzeugen überschreibt diese Änderungen.\n\n'
        '${zustand.path.split(RegExp(r'[\\/]')).last}',
    bestaetigung: 'Neu erzeugen',
  );
}
