import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

/// Die Rückfrage vor einer Übernahme im laufenden Betrieb (§7.2).
///
/// Beim Start steht dieselbe Frage als eigener Bildschirm; hier ist sie ein
/// Dialog, weil die Anwendung schon offen ist. Genau das ist auch der
/// Unterschied im Text: Ansichten, Formulare und Listen halten in diesem Moment
/// Daten des alten Bestands. Deshalb der Hinweis auf den Neustart — derselbe
/// Satz wie beim Einspielen von Hand.
abstract final class UebergabeUebernahmeDialog {
  /// Fragt nach und übernimmt bei Zustimmung. Liefert die Meldung des Backends,
  /// oder null, wenn abgebrochen wurde.
  static Future<String?> frageUndUebernimm(
    BuildContext context,
    UebergabeAngebot angebot,
  ) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stand von ${angebot.rechnername} übernehmen?'),
        content: Text(
          'Dort wurde ${SicherungsZeitpunkt.beschreibe(angebot.zuletztGearbeitet)} '
          'gearbeitet; der Stand ist von '
          '${SicherungsZeitpunkt.beschreibe(angebot.gesichertAm)}.\n\n'
          'Dabei werden alle Daten auf diesem Rechner durch diesen Stand '
          'ersetzt. Der bisherige Stand wird zuvor automatisch als '
          'Sicherungskopie abgelegt. Nach dem Übernehmen die App bitte neu '
          'starten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true) return null;

    try {
      return await getIt<BackupRepository>().uebernehmeStand();
    } catch (fehler) {
      // Das Backend spielt alles oder nichts ein — der eigene Stand ist
      // unberührt, und genau das muss dastehen.
      return 'Der Stand konnte nicht übernommen werden: $fehler '
          'Auf diesem Rechner hat sich nichts geändert.';
    }
  }
}
