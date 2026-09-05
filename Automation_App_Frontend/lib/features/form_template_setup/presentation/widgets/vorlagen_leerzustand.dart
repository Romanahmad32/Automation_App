import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';

/// Der erste Bildschirm einer neuen Vorlage: „Womit fängt diese Vorlage an?"
/// (#104, §5.3) — der Einstieg in den Ablauf **Datei zuerst**.
///
/// Vorher stand hier ein leeres Namensfeld und darunter zwei Karten mit
/// Dateiauswahl. Der Anwalt musste sich einen Namen ausdenken, bevor er die
/// Datei gewählt hatte, aus deren Namen er ohnehin abschreiben würde — und
/// eine leere Feldertabelle daneben sah aus, als sei etwas kaputt. Hier gibt
/// es genau eine Handlung: eine der beiden Word-Dateien wählen. Alles Weitere
/// (Name, Felder) leitet die App daraus ab.
///
/// **Die beiden Wahlflächen sind gleich groß und gleich gestaltet**, weil die
/// beiden Word-Dateien gleichwertig sind. Keine ist „die zweite" oder
/// optional, keine steht oben und die andere klein darunter — welche der
/// Anwalt zuerst hat, ist Zufall der Ablage.
class VorlagenLeerzustand extends StatelessWidget {
  /// Ruft den Dateidialog für diesen Slot — dieselbe Auswahl wie an der
  /// `TemplateFileSlotCard`, nur an der Stelle, an der der Anwalt anfängt.
  final void Function(TemplateFileSlot slot) onDateiWaehlen;

  /// Ab dieser Breite stehen die beiden Flächen nebeneinander. Darunter
  /// untereinander — nicht schmaler: Bei der größten Schriftstufe (#57)
  /// brauchen Titel und Erklärung ihre Zeile, und ein Knopf, der aus seiner
  /// Fläche läuft, ist schlimmer als ein zweiter Blattwechsel.
  static const double zweispaltigAb = 520;

  const VorlagenLeerzustand({super.key, required this.onDateiWaehlen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              'Womit fängt diese Vorlage an?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) =>
                  _wahlflaechen(context, constraints.maxWidth),
            ),
            Text(
              'Eine der beiden Dateien genügt. Platzhalter im Format {{Name}} '
              'werden erkannt und zu Feldern.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wahlflaechen(BuildContext context, double breite) {
    final kacheln = [
      _wahl(
        context,
        slot: TemplateFileSlot.ohneAuflistung,
        titel: 'Ohne Schadensaufstellung',
        erklaerung: 'Anspruchsschreiben ohne Positionsliste',
      ),
      _wahl(
        context,
        slot: TemplateFileSlot.mitAuflistung,
        titel: 'Mit Schadensaufstellung',
        erklaerung: 'Anspruchsschreiben mit {{Schadensaufstellung}}-Tabelle',
      ),
    ];

    // `isFinite` ist kein Zierrat: In einer waagerecht scrollenden Umgebung
    // wäre die Breite unbeschränkt, und `Expanded` in einer Zeile ohne Grenze
    // wirft.
    if (!breite.isFinite || breite < zweispaltigAb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: kacheln,
      );
    }
    // `IntrinsicHeight` + `stretch`: Nebeneinander sind beide Flächen so hoch
    // wie die höhere. Ohne das machte die längere Erklärung die eine Wahl
    // größer als die andere — und größer liest sich als „die richtige".
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [for (final kachel in kacheln) Expanded(child: kachel)],
      ),
    );
  }

  Widget _wahl(
    BuildContext context, {
    required TemplateFileSlot slot,
    required String titel,
    required String erklaerung,
  }) {
    final theme = Theme.of(context);
    return Container(
      // Der Schlüssel benennt die Fläche für den Test — zwei gleich
      // beschriftete Knöpfe sind sonst nicht auseinanderzuhalten.
      key: ValueKey(slot),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Row(
            spacing: 10,
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  titel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(erklaerung, style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: CustomRectangularButton(
              icon: const Icon(Icons.file_open),
              label: const Text('Datei wählen…'),
              onPressed: () => onDateiWaehlen(slot),
            ),
          ),
        ],
      ),
    );
  }
}
