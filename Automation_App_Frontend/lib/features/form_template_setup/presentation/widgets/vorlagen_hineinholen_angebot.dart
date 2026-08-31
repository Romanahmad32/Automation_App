import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_hineinholen.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:flutter/material.dart';

/// Bietet nach der Dateiauswahl an, eine außerhalb des Vorlagenordners
/// liegende Word-Datei hineinzukopieren (#33): außerhalb bleibt sie zwar
/// nutzbar (absolut verknüpft), wird aber nicht mitgesichert und fehlt auf
/// einem zweiten Rechner. Ablehnen ist erlaubt — dann bleibt der gewählte
/// Pfad.
class VorlagenHineinholenAngebot {
  const VorlagenHineinholenAngebot._();

  /// Liefert den zu verwendenden Pfad: den neuen im Vorlagenordner, wenn der
  /// Anwalt dem Kopieren zustimmt, sonst den gewählten unverändert.
  static Future<String> bieteAn(BuildContext context, String path) async {
    final uebersicht = await getIt<UseCase<VorlagenUebersicht, NoParams>>()(
      const NoParams(),
    );
    final ordner = switch (uebersicht) {
      Right(value: final u) => u.verzeichnis,
      Left() => null,
    };
    if (ordner == null ||
        VorlagenHineinholen.liegtImOrdner(ordner, path) ||
        !context.mounted) {
      return path;
    }

    final kopieren = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('In den Vorlagenordner kopieren?'),
        content: Text(
          'Die gewählte Datei liegt außerhalb des Vorlagenordners:\n$path\n\n'
          'Nur Dateien im Vorlagenordner werden mitgesichert und stehen '
          'damit auch auf einem zweiten Rechner zur Verfügung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Pfad behalten'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kopieren'),
          ),
        ],
      ),
    );
    if (kopieren != true) {
      return path;
    }

    final neuerPfad = await VorlagenHineinholen.kopiere(
      ordner: ordner,
      quelle: path,
    );
    if (neuerPfad == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Im Vorlagenordner liegt bereits eine gleichnamige Datei — '
              'nichts wurde überschrieben, der gewählte Pfad bleibt.',
            ),
          ),
        );
      }
      return path;
    }
    return neuerPfad;
  }
}
