import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_vorschlag_banner.dart';
import 'package:flutter/material.dart';

/// Meldet an einer Importzeile, dass es im Register schon einen **ähnlich**
/// geschriebenen Mandanten gibt — „Schmitt" bei vorhandenem „Schmidt".
///
/// Der Import vergleicht Namen getrimmt und kleingeschrieben, wie das Register
/// selbst; für diese Regel sind das zwei Personen, und das ist richtig so.
/// Innerhalb **einer** Datei sieht der Erzeuger beide Ordner nebeneinander und
/// führt sie zusammen — zwischen zwei Sitzungen sieht er nur den zweiten. Genau
/// diese Lücke schließt der Hinweis, und zwar mit derselben Erkennung wie das
/// Vorgangsformular ([MandantErkennung]), nicht mit einer zweiten.
///
/// „Übernehmen" schreibt nur den **Namen** der Zeile auf die Schreibweise des
/// Registers um. Zuordnen tut weiterhin der Dienst: Er prüft danach die ganze
/// Datei neu und macht aus der Zeile von selbst ein `ergaenzt`. Örtlich
/// nachzurechnen, was sich dadurch ändert, wäre eine zweite Auslegung derselben
/// Regeln.
class AehnlicherMandantHinweis extends StatelessWidget {
  /// Die gefundenen Ähnlichkeiten. Leer heißt: nichts anzeigen.
  final List<MandantVorschlag> vorschlaege;

  /// Übernimmt die Schreibweise dieses Registereintrags in die Zeile.
  final ValueChanged<Mandant> onUebernehmen;

  const AehnlicherMandantHinweis({
    super.key,
    required this.vorschlaege,
    required this.onUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    if (vorschlaege.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    // Derselbe Ton wie der Vorschlag im Vorgangsformular: ein Angebot, keine
    // Beanstandung. Rot wäre falsch — die Zeile ist nicht fehlerhaft.
    final tone = SoftTone.fromAccent(colorScheme.tertiary, colorScheme);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_search_outlined,
                  size: 18,
                  color: tone.foreground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vorschlaege.length == 1
                        ? 'Ähnlicher Name im Register:'
                        : 'Ähnliche Namen im Register:',
                    style: TextStyle(color: tone.foreground),
                  ),
                ),
              ],
            ),
            for (final vorschlag in vorschlaege)
              MandantVorschlagZeile(
                vorschlag: vorschlag,
                foreground: tone.foreground,
                onUebernehmen: () => onUebernehmen(vorschlag.mandant),
              ),
          ],
        ),
      ),
    );
  }
}
