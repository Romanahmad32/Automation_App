import 'dart:async';

import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// „Aktualisieren …“ in „Über diese Anwendung“ und im Einstellungen-Reiter
/// „Über“: öffnet den Dialog „App aktualisieren“ (#196).
///
/// Bis #196 hieß er `UpdateHerunterladenButton` und schickte auf die
/// Release-Seite. Jetzt lädt und installiert der Dienst; der Knopf führt nur
/// in den Dialog, der dasselbe zeigt wie der Hinweis in der Seitenleiste. Die
/// Auslassungspunkte sagen, dass erst ein Dialog kommt und noch nichts
/// geschieht.
class AktualisierenButton extends StatelessWidget {
  static const Key schluessel = ValueKey('aktualisierung-oeffnen');

  const AktualisierenButton({this.danach, super.key});

  /// Wird vor dem Öffnen aufgerufen — in „Über diese Anwendung“, um diesen
  /// Dialog zu schließen, damit nicht zwei übereinander stehen.
  final VoidCallback? danach;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: schluessel,
      onPressed: () {
        // Vor `danach` fassen: Schließt das den Dialog, in dem der Knopf
        // sitzt, ist dessen Kontext weg — der Navigator bleibt.
        final navigator = Navigator.of(context, rootNavigator: true);
        danach?.call();
        unawaited(AktualisierungsDialog.zeigen(navigator.context));
      },
      icon: const Icon(Icons.system_update),
      label: const Text('Aktualisieren …'),
    );
  }
}
