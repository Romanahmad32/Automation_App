import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_vorschlag_banner.dart';
import 'package:flutter/material.dart';

/// „Ähnlicher Name im Register" — der Hinweis im Bearbeiten-Dialog, dass diese
/// Zeile womöglich einen Mandanten anlegt, den es schon gibt.
///
/// Genau hier entsteht die Dublette: Der Dienst hat die Zeile als `neu`
/// eingestuft, weil ihr Name nicht **gleich** ist — „Schmitt" statt „Schmidt"
/// reicht dafür. Ein Mensch sieht den Zusammenhang sofort, die
/// Namensgleichheitsprüfung des Registers nicht. Der Vorschlag steht deshalb
/// dort, wo der Anwalt die Zeile ohnehin ansieht, und nicht in einer Liste,
/// die er hinterher noch einmal durchgehen müsste.
///
/// Gerechnet wird nichts: die Treffer kommen fertig aus `ImportAehnlichkeit`,
/// die ihrerseits `MandantErkennung` benutzt — dieselbe Erkennung wie im
/// Formular „Vorgang starten". Übernommen wird nur der **Name**; die Zuordnung
/// zum vorhandenen Mandanten trifft danach wieder der Dienst.
///
/// Die Zeilendarstellung ist [MandantVorschlagZeile] aus „Vorgang starten" —
/// dasselbe Bild für denselben Vorgang. Das Banner darum ist eigen, weil jenes
/// an `ReactiveFormConsumer` und an die Feldnamen des Vorgangsformulars hängt.
class ImportAehnlichkeitsHinweis extends StatelessWidget {
  /// Die ähnlichen Registereinträge zu dieser Zeile. Leer heißt: kein Hinweis.
  final List<MandantVorschlag> vorschlaege;

  /// Übernimmt den Namen des vorgeschlagenen Mandanten in die Zeile.
  final ValueChanged<Mandant> onUebernehmen;

  const ImportAehnlichkeitsHinweis({
    super.key,
    required this.vorschlaege,
    required this.onUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    if (vorschlaege.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    // Nicht `tertiaryContainer`: die *Container-Rollen sind im Light-Mode mit
    // sehr dunklen Markenfarben belegt und ergäben einen harten Kasten mitten
    // im Formular.
    final tone = SoftTone.fromAccent(farben.tertiary, farben);

    return Card(
      margin: EdgeInsets.zero,
      color: tone.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_search_outlined, color: tone.foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ähnlicher Name im Register',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tone.foreground,
                    ),
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
