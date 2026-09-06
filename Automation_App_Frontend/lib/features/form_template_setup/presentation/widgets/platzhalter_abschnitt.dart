import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_placeholders_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die erkannten {{Platzhalter}} beider Word-Dateien — **zugeklappt** unter
/// einer Zählzeile (#104 Stufe 3a).
///
/// Bis Stufe 2 standen die Chips in der Dateikarte, direkt unter dem
/// Dateinamen. In der schmalen linken Spalte des zweispaltigen Editors sind
/// das je Datei zwei Dutzend Chips über der Stand-Karte und der Feldertabelle
/// — genau vor dem, worauf es ankommt. Die Chips sind aber ein Nachschlagewerk
/// („welche Namen stehen eigentlich in der Datei?") und nur beim Einrichten
/// einer neuen Vorlage eine Aufgabe; die Aufgaben selbst sagt die Stand-Karte.
/// Also derselbe Griff wie bei `AppEigenePlatzhalterListe`: Karte mit
/// [ExpansionTile], zugeklappt eine Zeile, aufgeklappt der volle Bestand.
///
/// **Gezählt wird über beide Dateien zusammen und jeder Name nur einmal** —
/// dieselbe Regel wie in `VorlagenStand` (siehe `FALLSTRICKE.md`): Ein
/// Platzhalter, der in der Datei ohne *und* der Datei mit Auflistung steht,
/// ist ein Platzhalter. Je Datei getrennt gezählt stand hier früher eine Zahl,
/// die für die Vorlage nichts bedeutete.
class PlatzhalterAbschnitt extends StatelessWidget {
  /// Klick auf einen offenen Chip — führt zur Zuordnung (#36).
  final void Function(String placeholder) onPlaceholderSelected;

  /// Die aktuell eingetragenen Feldnamen, für die Chip-Optik „übernommen".
  final Iterable<String?> vorhandeneNamen;

  const PlatzhalterAbschnitt({
    super.key,
    required this.onPlaceholderSelected,
    this.vorhandeneNamen = const [],
  });

  /// Die Aufschrift über der Chip-Liste einer Datei.
  ///
  /// Kürzer als die Überschrift der Dateikarte („Vorlage ohne Auflistung
  /// (HGn)"): Dort benennt sie die Datei samt Zweck, hier trennt sie nur zwei
  /// Chip-Listen voneinander, die ohnehin schon in einem Abschnitt namens
  /// „Platzhalter je Datei" stehen.
  static String slotTitel(TemplateFileSlot slot) => switch (slot) {
    TemplateFileSlot.ohneAuflistung => 'Ohne Auflistung (HGn)',
    TemplateFileSlot.mitAuflistung => 'Mit Auflistung',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, zustand) {
        // Nur Dateien, zu denen etwas vorliegt. Ohne jede Verknüpfung hätte
        // der Abschnitt keinen Inhalt — dann steht er auch nicht da und nimmt
        // der Stand-Karte darüber keine Aufmerksamkeit weg.
        final slots = [
          for (final slot in TemplateFileSlot.values)
            if (zustand.forSlot(slot) is! SlotPlaceholdersInitial) slot,
        ];
        if (slots.isEmpty) return const SizedBox.shrink();

        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Platzhalter je Datei anzeigen'),
            subtitle: Text(
              _zaehlzeile(zustand, slots),
              style: theme.textTheme.bodySmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final slot in slots) ..._dateiblock(theme, slot)],
          ),
        );
      },
    );
  }

  List<Widget> _dateiblock(ThemeData theme, TemplateFileSlot slot) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        slotTitel(slot),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    TemplatePlaceholdersView(
      slot: slot,
      onPlaceholderSelected: onPlaceholderSelected,
      vorhandeneNamen: vorhandeneNamen,
    ),
    const SizedBox(height: 16),
  ];

  /// Die eine Zeile, die zugeklappt zu sehen ist.
  String _zaehlzeile(
    TemplatePlaceholdersState zustand,
    List<TemplateFileSlot> slots,
  ) {
    final dateien = slots.length == 1 ? '1 Datei' : '${slots.length} Dateien';
    final ergebnisse = [for (final slot in slots) zustand.forSlot(slot)];
    if (ergebnisse.any((ergebnis) => ergebnis is SlotPlaceholdersLoading)) {
      return 'Platzhalter werden gelesen …';
    }

    // Kleingeschrieben verglichen, weil das Backend die Platzhalter beim
    // Ersetzen ebenfalls ohne Rücksicht auf Groß-/Kleinschreibung sucht
    // (siehe FEATURE.md): `{{Frist}}` und `{{frist}}` sind derselbe.
    final namen = {
      for (final ergebnis in ergebnisse.whereType<SlotPlaceholdersLoaded>())
        ...ergebnis.placeholders.map((name) => name.toLowerCase()),
    };
    final anzahl = namen.length == 1
        ? '1 Platzhalter'
        : '${namen.length} Platzhalter';
    return '$anzahl in $dateien';
  }
}
