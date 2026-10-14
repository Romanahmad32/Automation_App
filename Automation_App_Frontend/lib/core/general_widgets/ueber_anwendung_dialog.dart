import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierung_builder.dart';
import 'package:automation_app/core/general_widgets/aktualisieren_button.dart';
import 'package:automation_app/core/general_widgets/anwendungs_info.dart';
import 'package:material_ui/material_ui.dart';

/// „Über diese Anwendung" — der Dialog hinter dem Versionsschild in der
/// Seitenleiste. Liest den Stand der Aktualisierung selbst, statt ihn beim
/// Öffnen mitzubekommen: Antwortet die Prüfung erst, während er offen ist,
/// erscheint der Knopf noch.
class UeberAnwendungDialog extends StatelessWidget {
  const UeberAnwendungDialog({super.key});

  static Future<void> zeigen(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const UeberAnwendungDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return AktualisierungBuilder(
      builder: (context, ansicht) => AlertDialog(
        title: const Text('Über diese Anwendung'),
        content: SizedBox(width: 420, child: AnwendungsInfo(ansicht: ansicht)),
        actions: [
          if (ansicht?.updateInSicht ?? false)
            AktualisierenButton(danach: () => Navigator.of(context).pop()),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
