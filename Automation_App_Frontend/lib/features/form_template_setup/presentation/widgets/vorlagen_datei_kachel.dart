import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagenname_vorschlag.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_status_zeile.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_datei_oeffnen.dart';
import 'package:flutter/material.dart';

/// Eine der beiden Wahlflächen der Auswahlseite („Womit fängt diese Vorlage
/// an?", `VorlagenLeerzustand`, #104): Titel, Erklärung — und **ihr Zustand**.
///
/// Bis Stufe 4 war die Fläche ein blosser Knopf: Der erste gesetzte Pfad ließ
/// den Leerzustand verschwinden, und was gewählt worden war, sah man erst im
/// Editor. Der Anwalt will beide Dateien aber an **einer** Stelle verknüpfen
/// (Gleichwertigkeit, §5.3) und dabei sehen, was schon dasteht. Deshalb bleibt
/// die Fläche stehen und trägt jetzt selbst, was zur Datei zu sagen ist:
/// Dateiname, Lesezustand und die drei Handlungen daran.
///
/// **Eigener Baustein und nicht in `vorlagen_leerzustand.dart`**: Dort hätte
/// er das Zeilenbudget gerissen (`file_length_test.dart`), und die Kachel ist
/// für sich prüfbar — ohne Bloc, weil sie ihren [zustand] übergeben bekommt.
///
/// **Nicht dieselbe Karte wie `TemplateFileSlotCard`**: Die beantwortet im
/// Editor dieselbe Frage, steht dort aber in einer 400 px schmalen Spalte,
/// trägt die Warnung zur fehlenden {{Schadensaufstellung}} und hat einen
/// Kartenrahmen. Hier zählt die Gleichwertigkeit der beiden Flächen
/// (gleich groß, gleich gestaltet, nebeneinander) und der eine nächste
/// Schritt. Was beide teilen, ist die Mechanik — `PlatzhalterStatusZeile` und
/// [VorlagenDateiOeffnen], nicht die Gestalt.
class VorlagenDateiKachel extends StatelessWidget {
  /// Welche der beiden Word-Dateien. Er wird auch zum [ValueKey] der Fläche:
  /// Beide tragen dieselben Aufschriften und sind im Test sonst nicht
  /// auseinanderzuhalten.
  final TemplateFileSlot slot;

  final String titel;
  final String erklaerung;

  /// Der verknüpfte Pfad — null heißt: noch keine Datei gewählt.
  final String? pfad;

  /// Der Lesezustand **dieses** Slots. Übergeben statt selbst aus dem Bloc
  /// geholt: So bleibt die Kachel ohne Bloc prüfbar, und die Auswahlseite
  /// horcht einmal für beide.
  final SlotPlaceholders zustand;

  /// „Datei wählen…" bzw. „Andere Datei wählen" — dieselbe Handlung, nur mit
  /// anderer Aufschrift.
  final VoidCallback onWaehlen;

  final VoidCallback onEntfernen;

  const VorlagenDateiKachel({
    super.key,
    required this.slot,
    required this.titel,
    required this.erklaerung,
    required this.pfad,
    required this.zustand,
    required this.onWaehlen,
    required this.onEntfernen,
  });

  @override
  Widget build(BuildContext context) {
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
        children: [_kopf(theme), ..._inhalt(context, theme)],
      ),
    );
  }

  Widget _kopf(ThemeData theme) => Row(
    spacing: 10,
    children: [
      Icon(Icons.description_outlined, color: theme.colorScheme.primary),
      Expanded(
        child: Text(
          titel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  /// Erklärung, Stand und Handlungen — die beiden Fassungen der Kachel.
  ///
  /// Der Pfad wird in eine **lokale** Variable gelesen: Erst dadurch weiß der
  /// Übersetzer im zweiten Zweig, dass er nicht null ist, und die drei
  /// Aufrufstellen darunter brauchen kein `!`.
  List<Widget> _inhalt(BuildContext context, ThemeData theme) {
    final erklaerungsZeile = Text(erklaerung, style: theme.textTheme.bodySmall);
    final pfad = this.pfad;
    if (pfad == null) {
      return [
        erklaerungsZeile,
        Text(
          'Noch keine Datei gewählt',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: CustomRectangularButton(
            icon: const Icon(Icons.file_open),
            label: const Text('Datei wählen…'),
            onPressed: onWaehlen,
          ),
        ),
      ];
    }
    return [
      erklaerungsZeile,
      _dateizeile(theme, pfad),
      // Die Zahl statt eines stillen „fertig": Auf dieser Seite steht weder
      // die Feldertabelle noch die Stand-Karte daneben, und ohne Zahl wüsste
      // niemand, ob die Datei überhaupt gelesen wurde.
      PlatzhalterStatusZeile(zustand: zustand, zeigtAnzahl: true),
      _knoepfe(context, pfad),
    ];
  }

  /// Nur der **Dateiname**, der volle Pfad im Tooltip: Mit Verzeichnis erkennt
  /// niemand mehr, welches Dokument das ist (dasselbe Muster wie
  /// `EmailAnhangChip`).
  Widget _dateizeile(ThemeData theme, String pfad) => Row(
    spacing: 10,
    children: [
      Icon(Icons.description, color: theme.colorScheme.primary),
      Expanded(
        child: Tooltip(
          message: pfad,
          child: Text(
            VorlagennameVorschlag.dateiname(pfad),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
  );

  /// Die drei Handlungen an einer verknüpften Datei.
  ///
  /// `Wrap` statt `Row` und aus demselben Grund wie in
  /// `TemplateFileSlotCard._knoepfe`: Nebeneinander ist eine Kachel halb so
  /// breit wie die Seite, und „Andere Datei wählen" ist bei angehobener
  /// Schrift (Issue #57) allein schon breiter als der Platz neben einem
  /// zweiten Knopf. Das Entfernen steht **hinten** — es ist die einzige
  /// Handlung hier, die etwas wegnimmt.
  Widget _knoepfe(BuildContext context, String pfad) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      CustomRectangularButton(
        icon: const Icon(Icons.edit_document),
        label: const Text('In Word öffnen'),
        onPressed: () => VorlagenDateiOeffnen.inWord(context, pfad),
      ),
      CustomRectangularButton(
        icon: const Icon(Icons.file_open),
        label: const Text('Andere Datei wählen'),
        onPressed: onWaehlen,
      ),
      IconButton(
        tooltip: 'Verknüpfung entfernen',
        icon: const Icon(Icons.close),
        onPressed: onEntfernen,
      ),
    ],
  );
}
