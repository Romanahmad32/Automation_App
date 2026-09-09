import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

/// Die Rückfrage vor einer Übernahme im laufenden Betrieb (§7.2).
///
/// Beim Start steht dieselbe Frage als eigener Bildschirm; hier ist sie ein
/// Dialog, weil die Anwendung schon offen ist. Genau das ist auch der
/// Unterschied im Text: Ansichten, Formulare und Listen halten in diesem Moment
/// Daten des alten Bestands. Deshalb werden sie nach der Übernahme neu geladen;
/// ungespeicherte Eingaben müssen vorher gesichert werden.
abstract final class UebergabeUebernahmeDialog {
  /// Fragt nach und übernimmt bei Zustimmung. Liefert die Meldung des Backends,
  /// oder null, wenn abgebrochen wurde.
  static Future<String?> frageUndUebernimm(
    BuildContext context,
    UebergabeAngebot angebot, {
    String? pruefkennung,
    bool konflikt = false,
  }) async {
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Stand von ${angebot.rechnername} übernehmen?',
      text:
          'Dort wurde ${SicherungsZeitpunkt.beschreibe(angebot.zuletztGearbeitet)} '
          'gearbeitet; der Stand ist von '
          '${SicherungsZeitpunkt.beschreibe(angebot.gesichertAm)}.\n\n'
          '${konflikt ? 'Achtung: Auf beiden Rechnern liegen unterschiedliche Änderungen vor. Sie werden nicht zusammengeführt. ' : ''}'
          'Dabei werden alle Daten auf diesem Rechner durch diesen Stand '
          'ersetzt. Der bisherige Stand wird zuvor automatisch als '
          'Sicherungskopie abgelegt. Bitte offene Eingaben zuerst speichern. '
          'Nach der Übernahme werden alle Ansichten neu geladen; nicht gespeicherte Eingaben werden verworfen.',
      bestaetigung: 'Übernehmen',
    );
    if (!bestaetigt) return null;

    try {
      return await getIt<BackupRepository>().uebernehmeStand(
        pruefkennung: pruefkennung,
        konfliktBestaetigt: konflikt,
      );
    } catch (fehler) {
      // Eine verlorene HTTP-Antwort lässt offen, ob die Übernahme gelang.
      return 'Der Stand konnte nicht übernommen werden: $fehler '
          'Bitte den Datenstand erneut prüfen. Eine fehlende Bestätigung kann auch durch eine unterbrochene Verbindung entstehen.';
    }
  }
}
