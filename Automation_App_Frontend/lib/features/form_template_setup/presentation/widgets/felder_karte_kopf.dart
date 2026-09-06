import 'package:automation_app/features/form_template_setup/domain/services/felder_filter.dart';
import 'package:flutter/material.dart';

/// Die Kopfzeile der Felderkarte: Titel „Felder (18)", die Filterauswahl und
/// das ⋯-Menü.
///
/// Der Knopf „Neues Feld hinzufügen" stand hier früher gross und rechts —
/// neben dem Filter, den der Anwalt an einem Arbeitstag zwanzigmal umstellt,
/// und der Handlung, die er einmal je Vorlage braucht. Er ist deshalb ins
/// ⋯-Menü gewandert; der Regelweg zu einem neuen Feld führt ohnehin über
/// einen Platzhalter-Chip der Dateikarte, nicht über eine leere Zeile.
///
/// `Wrap` statt `Row` mit `Spacer`: Bei angehobener Schrift (Issue #57) und
/// schmalem Fenster reicht die Breite nicht mehr für Titel **und** Auswahl
/// nebeneinander — ein Spacer kann dann nicht auf negative Breite schrumpfen
/// und die Karte läuft rechts über. Der Filter rutscht stattdessen unter den
/// Titel.
class FelderKarteKopf extends StatelessWidget {
  final int anzahlFelder;

  /// Der gewählte Filter, oder null: Dann ist über die Vorlage noch nichts
  /// gerechnet ([FelderFilter] braucht den `VorlagenStand`) und die Auswahl
  /// bleibt weg, statt Knöpfe ohne Zahlen zu zeigen.
  final FelderFilter? filter;

  final ValueChanged<FelderFilter> onFilter;

  /// Die Zahl auf einem Filterknopf; null heißt „ohne Zahl".
  final int? Function(FelderFilter filter) zahl;

  final VoidCallback onNeuesFeld;

  const FelderKarteKopf({
    super.key,
    required this.anzahlFelder,
    required this.filter,
    required this.onFilter,
    required this.zahl,
    required this.onNeuesFeld,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Icon(Icons.input, color: theme.colorScheme.primaryContainer),
            Text(
              'Felder ($anzahlFelder)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            // `Flexible`, weil der Auswahlknopf bei der größten Schriftstufe
            // (Issue #57) breiter wird als ein 700-px-Fenster:
            // `SegmentedButton` deckelt seine Segmente auf `maxWidth / Anzahl`
            // und kürzt die Aufschriften dann mit Auslassung, statt die Karte
            // zu sprengen.
            if (filter != null) Flexible(child: _auswahl(filter!)),
            _menue(),
          ],
        ),
      ],
    );
  }

  /// Die drei Filter als ein Knopf. Das Häkchen vor der gewählten Aufschrift
  /// bleibt an (`auswahl_sichtbar_test.dart`): Es ist die einzige Markierung,
  /// die auch bei geringem Farbkontrast trägt. Den Platz bei der größten
  /// Schriftstufe löst das `Flexible` darum herum, nicht das Abschalten.
  Widget _auswahl(FelderFilter gewaehlt) {
    return SegmentedButton<FelderFilter>(
      segments: [
        for (final wert in FelderFilter.values)
          ButtonSegment(
            value: wert,
            label: Text(
              wert.beschriftungMitZahl(zahl(wert)),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selected: {gewaehlt},
      onSelectionChanged: (auswahl) => onFilter(auswahl.first),
    );
  }

  /// Das ⋯-Menü. `constraints` gibt ihm mehr Breite als die Vorgabe, und der
  /// Text steht in einem `Expanded`: Der erklärende Untertitel ist länger als
  /// ein Menüeintrag üblicherweise, und bei angehobener Schrift bräche er
  /// sonst rechts aus dem Menü aus, statt umzubrechen.
  Widget _menue() {
    return PopupMenuButton<int>(
      tooltip: 'Weitere Aktionen',
      icon: const Icon(Icons.more_horiz),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 420),
      onSelected: (_) => onNeuesFeld(),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              const Icon(Icons.add),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Neues Feld von Hand'),
                    Text(
                      'Platzhalter wird erst noch in Word ergänzt',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
