import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/general_widgets/anwendungs_info.dart';
import 'package:automation_app/core/general_widgets/update_herunterladen_button.dart';
import 'package:flutter/material.dart';

/// „Über diese Anwendung" — der Dialog hinter dem Versionsschild und dem
/// Update-Hinweis in der Seitenleiste.
class UeberAnwendungDialog extends StatelessWidget {
  const UeberAnwendungDialog({required this.stand, super.key});

  final AktualisierungsErgebnis? stand;

  static Future<void> zeigen(
    BuildContext context,
    AktualisierungsErgebnis? stand,
  ) => showDialog<void>(
    context: context,
    builder: (_) => UeberAnwendungDialog(stand: stand),
  );

  @override
  Widget build(BuildContext context) {
    final neu = stand?.neueVersion;

    return AlertDialog(
      title: const Text('Über diese Anwendung'),
      content: SizedBox(width: 420, child: AnwendungsInfo(stand: stand)),
      actions: [
        if (neu != null)
          UpdateHerunterladenButton(
            neueVersion: neu,
            danach: () => Navigator.of(context).pop(),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
