import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Bietet den erkannten synchronisierten Ordner mit einem Klick an. Erscheint
/// nur, solange das Feld leer ist und ein solcher Ordner gefunden wurde.
///
/// Genutzt von der Register-Ablage (§6.2) und der Sicherungsablage (§7.2) — sie
/// unterscheiden sich nur im Feld und im vorgeschlagenen Unterordner.
///
/// Zustandsbehaftet wegen einer Kleinigkeit mit spürbaren Folgen: Die Suche
/// sieht auf der Platte nach, ob der Ordner aus der Umgebungsvariablen wirklich
/// existiert. Im `build` stünde sie damit bei **jedem** Neuzeichnen des
/// Formulars — bei jedem Tastendruck im Feld daneben — und bei einem getrennten
/// oder auf „Dateien bei Bedarf" gestellten OneDrive dauert schon das
/// Nachsehen. So läuft sie einmal beim Aufbauen, und zwar nebenläufig.
class SynchronisierterOrdnerVorschlag extends StatefulWidget {
  /// Das Feld, in das der Vorschlag geschrieben wird.
  final String formControlName;

  /// Unterordner unter dem erkannten OneDrive-Pfad.
  final String unterordner;

  const SynchronisierterOrdnerVorschlag({
    super.key,
    required this.formControlName,
    required this.unterordner,
  });

  @override
  State<SynchronisierterOrdnerVorschlag> createState() =>
      SynchronisierterOrdnerVorschlagState();
}

class SynchronisierterOrdnerVorschlagState
    extends State<SynchronisierterOrdnerVorschlag> {
  late final Future<String?> _gesucht = SynchronisierterOrdner.suche(
    unterordner: widget.unterordner,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _gesucht,
    builder: (context, ergebnis) {
      final vorschlag = ergebnis.data;
      // Solange gesucht wird, steht hier nichts: Ein Platzhalter für einen
      // Knopf, den es vielleicht gar nicht gibt, liesse das Formular springen.
      if (vorschlag == null) return const SizedBox.shrink();
      return _knopf(vorschlag);
    },
  );

  Widget _knopf(String vorschlag) {
    return ReactiveValueListenableBuilder<String>(
      formControlName: widget.formControlName,
      builder: (context, control, _) {
        if ((control.value ?? '').trim().isNotEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        // Der Pfad steht bewusst unter dem Knopf und nicht in seiner
        // Beschriftung: Ein Benutzerprofil mit langem Namen macht daraus sonst
        // eine Zeile, die aus dem Formular herausläuft.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => control.value = vorschlag,
              icon: const Icon(Icons.cloud_sync_outlined, size: 18),
              label: const Text('Erkannten OneDrive-Ordner übernehmen'),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                vorschlag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
