import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/paket_historie_tabelle.dart';
import 'package:flutter/material.dart';

/// Der Stand über dem Zuordnungsstapel: wie viele Ordner es gibt, wie viele
/// entschieden sind und wie viele noch offen — dazu die Paket-Historie zum
/// Aufklappen.
///
/// Das ist die Frage, die der Anwalt bei einem Vorgang über mehrere Tage jedes
/// Mal zuerst stellt, und sie stand bisher nirgends. Die Zahlen bleiben deshalb
/// sichtbar; die Historie klappt zu, weil der Stapel eine Arbeitsliste ist und
/// eine dauerhaft aufgeschlagene Tabelle ihr den Platz nähme, den die Liste
/// braucht.
class ZuordnungStandBand extends StatelessWidget {
  /// Alle im Stammordner gefundenen Ordner.
  final int gesamt;

  /// Davon einem Mandanten zugeordnet.
  final int zugeordnet;

  /// Davon als „ohne Mandantenbezug" vermerkt.
  final int ohneBezug;

  /// Weder das eine noch das andere — der Arbeitsvorrat.
  final int offen;

  /// Die herausgegebenen Pakete, neuestes zuerst.
  final List<Arbeitspaket> historie;

  const ZuordnungStandBand({
    super.key,
    required this.gesamt,
    required this.zugeordnet,
    required this.ohneBezug,
    required this.offen,
    this.historie = const [],
  });

  /// Pakete, deren Antwortdatei noch aussteht.
  int get _offenePakete => historie.where((p) => !p.eingelesen).length;

  String get _paketZeile {
    if (historie.isEmpty) return 'Noch kein Arbeitspaket geholt';
    final eingelesen = historie.length - _offenePakete;
    return 'Pakete: ${historie.length} geholt, $eingelesen eingelesen';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder_copy_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              // Umbrechen statt abschneiden: bei schmalem Fenster stehen die
              // Kennzahlen untereinander, aber keine fehlt.
              Expanded(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    ZuordnungKennzahl(wert: gesamt, was: 'gefunden'),
                    ZuordnungKennzahl(wert: zugeordnet, was: 'zugeordnet'),
                    ZuordnungKennzahl(
                      wert: ohneBezug,
                      was: 'ohne Mandantenbezug',
                    ),
                    ZuordnungKennzahl(
                      wert: offen,
                      was: 'offen',
                      hervorgehoben: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Randlos und ohne eigene Einrückung, damit der Aufklapper Teil
          // dieser Fläche bleibt und nicht wie eine zweite Karte darin wirkt.
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                _paketZeile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _offenePakete > 0 ? scheme.tertiary : scheme.outline,
                ),
              ),
              children: [PaketHistorieTabelle(historie: historie)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Kennzahl des [ZuordnungStandBand]s: Zahl und Beschriftung nebeneinander.
///
/// Eigenes Widget statt einer privaten Hilfsmethode, weil private Typen und
/// Top-Level-Funktionen hier nicht erlaubt sind — und weil sich die Zahl damit
/// einzeln prüfen lässt.
class ZuordnungKennzahl extends StatelessWidget {
  final int wert;
  final String was;

  /// Die eine Zahl, die auf null gehen soll, trägt die Akzentfarbe.
  final bool hervorgehoben;

  const ZuordnungKennzahl({
    super.key,
    required this.wert,
    required this.was,
    this.hervorgehoben = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$wert',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: hervorgehoben ? scheme.primary : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          was,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}
