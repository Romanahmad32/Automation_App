import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_datei_kachel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der erste Bildschirm einer neuen Vorlage: „Womit fängt diese Vorlage an?"
/// (#104, §5.3) — der Einstieg in den Ablauf **Datei zuerst**.
///
/// Vorher stand hier ein leeres Namensfeld und darunter zwei Karten mit
/// Dateiauswahl. Der Anwalt musste sich einen Namen ausdenken, bevor er die
/// Datei gewählt hatte, aus deren Namen er ohnehin abschreiben würde — und
/// eine leere Feldertabelle daneben sah aus, als sei etwas kaputt. Hier gibt
/// es genau eine Aufgabe: die Word-Dateien wählen, mit denen diese Vorlage
/// arbeitet. Alles Weitere (Name, Felder) leitet die App daraus ab.
///
/// **Die Seite bleibt stehen, bis der Anwalt „Weiter" drückt** (Stufe 5).
/// Bis dahin verschwand sie mit dem ersten gesetzten Pfad, und die zweite
/// Datei war nur noch im Editor zu finden — obwohl beide gleichwertig sind und
/// zusammen gewählt werden wollen. Wann Schluss ist, sagt jetzt
/// `VorlagenBearbeitung.auswahlAbgeschlossen`, nicht mehr der Zustand der
/// Pfade.
///
/// **Die beiden Wahlflächen sind gleich groß und gleich gestaltet**, weil die
/// beiden Word-Dateien gleichwertig sind. Keine ist „die zweite" oder
/// optional, keine steht oben und die andere klein darunter — welche der
/// Anwalt zuerst hat, ist Zufall der Ablage. Was in einer Fläche steht,
/// gehört [VorlagenDateiKachel].
class VorlagenLeerzustand extends StatelessWidget {
  /// Der Stand des Editors — hier gebraucht werden die beiden Word-Pfade.
  final VorlagenBearbeitung bearbeitung;

  /// Ruft den Dateidialog für diesen Slot — dieselbe Auswahl wie an der
  /// `TemplateFileSlotCard`, nur an der Stelle, an der der Anwalt anfängt.
  final void Function(TemplateFileSlot slot) onDateiWaehlen;

  /// Löst die Verknüpfung wieder — „doch die falsche Datei" ist beim Anlegen
  /// der häufige Weg, und ohne diesen Knopf führte er nur über den Editor.
  final void Function(TemplateFileSlot slot) onDateiEntfernen;

  /// Ab dieser Breite stehen die beiden Flächen nebeneinander. Darunter
  /// untereinander — nicht schmaler: Bei der größten Schriftstufe (#57)
  /// brauchen Titel und Erklärung ihre Zeile, und ein Knopf, der aus seiner
  /// Fläche läuft, ist schlimmer als ein zweiter Blattwechsel.
  static const double zweispaltigAb = 520;

  const VorlagenLeerzustand({
    super.key,
    required this.bearbeitung,
    required this.onDateiWaehlen,
    required this.onDateiEntfernen,
  });

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
            // Einmal für beide Flächen gehorcht: Der Lesezustand kommt je Slot
            // aus demselben Bloc, und zwei Horcher übereinander wären zwei
            // Neuaufbauten für dasselbe Ereignis.
            BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
              builder: (context, zustand) => LayoutBuilder(
                builder: (context, constraints) =>
                    _wahlflaechen(zustand, constraints.maxWidth),
              ),
            ),
            Text(
              'Eine der beiden Dateien genügt – beide sind gleichwertig. '
              'Platzhalter im Format {{Name}} werden erkannt und zu Feldern.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wahlflaechen(TemplatePlaceholdersState zustand, double breite) {
    final kacheln = [
      _wahl(
        zustand,
        slot: TemplateFileSlot.ohneAuflistung,
        // Der Zusatz „(HGn)" ist der Kanzleiname dieser Datei und steht
        // ebenso an der Dateikarte des Editors — dieselbe Datei darf nicht an
        // zwei Stellen zwei Namen tragen.
        titel: 'Ohne Schadensaufstellung (HGn)',
        erklaerung: 'Anspruchsschreiben ohne Positionsliste',
      ),
      _wahl(
        zustand,
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
    TemplatePlaceholdersState zustand, {
    required TemplateFileSlot slot,
    required String titel,
    required String erklaerung,
  }) {
    return VorlagenDateiKachel(
      slot: slot,
      titel: titel,
      erklaerung: erklaerung,
      pfad: bearbeitung.pfad(slot),
      zustand: zustand.forSlot(slot),
      onWaehlen: () => onDateiWaehlen(slot),
      onEntfernen: () => onDateiEntfernen(slot),
    );
  }
}
