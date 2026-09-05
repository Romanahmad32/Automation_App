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

  /// Was stattdessen dasteht, wenn **kein** synchronisierter Ordner erkennbar
  /// ist. `null` heißt: gar nichts — richtig für die Felder, die ohnehin nur
  /// eine Bequemlichkeit anbieten.
  ///
  /// Für den Ordner der App-Daten (#103) ist es umgekehrt: Dort ist der
  /// Vorschlag der Regelweg, und sein Ausbleiben ist die Erklärung, warum
  /// hier von Hand zu wählen ist. Ein leerer Fleck sähe aus wie ein Fehler
  /// der App.
  final String? hinweisOhneVorschlag;

  const SynchronisierterOrdnerVorschlag({
    super.key,
    required this.formControlName,
    required this.unterordner,
    this.hinweisOhneVorschlag,
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
      // Solange gesucht wird, steht hier nichts: Ein Platzhalter für einen
      // Knopf, den es vielleicht gar nicht gibt, liesse das Formular springen.
      // Deshalb wird der Suchstand abgefragt und nicht nur das Ergebnis — beim
      // Warten ist es genauso null wie bei „nichts gefunden".
      if (ergebnis.connectionState != ConnectionState.done) {
        return const SizedBox.shrink();
      }
      final vorschlag = ergebnis.data;
      if (vorschlag == null) return _hinweis(context);
      return _knopf(vorschlag);
    },
  );

  Widget _hinweis(BuildContext context) {
    final text = widget.hinweisOhneVorschlag;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

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
