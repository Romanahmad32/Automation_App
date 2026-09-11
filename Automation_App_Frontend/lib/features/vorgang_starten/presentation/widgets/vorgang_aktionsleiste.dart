import 'package:automation_app/core/general_widgets/form/formular_fehler_hinweis.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Unten angeheftete Aktionsleiste (scrollt nicht mit). Primäraktion „Vorgang
/// speichern"; bei Verkehrsrecht zusätzlich „Zentralruf-Formular ausfüllen"
/// (öffnet den Browser und speichert den Vorgang zugleich). Beide sind nur bei
/// gültigem Formular aktiv; während des Speicherns wird ein Ladeindikator gezeigt.
///
/// **Darüber steht, warum sie gesperrt sind** ([FormularFehlerHinweis], #130).
/// Diese Seite hatte eine solche Zeile bisher gar nicht: Wer ein Feld nur
/// vorbelegt bekam oder nach dem Tippen direkt auf den toten Knopf klickte, sah
/// nirgends eine Beanstandung — das Feld war nie „touched", und ein gesperrter
/// Knopf nimmt keinen Fokus.
class VorgangAktionsleiste extends StatelessWidget {
  final bool zeigeZentralruf;
  final VoidCallback onSpeichern;
  final VoidCallback onZentralruf;

  const VorgangAktionsleiste({
    super.key,
    required this.zeigeZentralruf,
    required this.onSpeichern,
    required this.onZentralruf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: BlocBuilder<VorgangStartenBloc, VorgangStartenState>(
              builder: (context, state) {
                final isLoading = state is VorgangStartenLoading;
                return ReactiveFormConsumer(
                  builder: (context, formGroup, child) {
                    final aktiv = formGroup.valid && !isLoading;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        FormularFehlerHinweis(
                          // Ohne [felder] gilt die ganze Gruppe — hier richtig,
                          // weil die Unfall-Felder ausserhalb des
                          // Verkehrsrechts abgeschaltet sind und deshalb gar
                          // nicht auftauchen können (`_applyUnfallValidators`).
                          // Ein Feld zu nennen, dessen Abschnitt nicht auf der
                          // Seite steht, hiesse in ein Nichts zu springen.
                          beschriftungen: vorgangFeldBeschriftungen,
                          // Beide teilen sich `ValidationMessage.pattern` und
                          // meinen Verschiedenes — ohne diese Zuordnung stünde in
                          // der Zeile nur „Format prüfen".
                          feldMeldungen: {
                            'unfalluhrzeit': uhrzeitMessages,
                            'polizeiVorgangsnummer': vorgangsnummerMessages,
                          },
                        ),
                        // OverflowBar statt Row: Bei "Am größten" (Issue #57) sind
                        // beide Beschriftungen auf einem schmalen Fenster
                        // zusammen breiter als die verfügbaren ~900 px — eine Row
                        // liefe rechts über, weil sie ihre Kinder nie umbrechen
                        // kann. OverflowBar stapelt sie stattdessen untereinander,
                        // rechtsbündig wie zuvor die Row.
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          overflowAlignment: OverflowBarAlignment.end,
                          spacing: 12,
                          overflowSpacing: 8,
                          children: [
                            if (zeigeZentralruf)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text(
                                  'Zentralruf-Formular ausfüllen',
                                ),
                                onPressed: aktiv ? onZentralruf : null,
                              ),
                            FilledButton.icon(
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Vorgang speichern'),
                              onPressed: aktiv ? onSpeichern : null,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
