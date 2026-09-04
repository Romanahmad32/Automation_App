import 'package:automation_app/core/general_widgets/layout/karten_spalten.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_aktionszeile.dart';
import 'package:flutter/material.dart';

/// Der Rumpf **eines** Einstellungs-Reiters: oben die
/// [EinstellungenAktionszeile], darunter der scrollende Inhalt in ein oder
/// zwei Kartenspalten.
///
/// Dass es diesen Baustein gibt, ist der eigentliche Punkt: Vorher baute jede
/// der sechs Ansichten ihre eigene Fassung aus `Scrollbar`,
/// `SingleChildScrollView`, `Center`, `ConstrainedBox` und `Padding` — und
/// jede etwas anders (560 px hier, 900 px dort, einmal ohne Bildlaufleiste).
/// Die Reiter kommen aus vier Features (`settings`, `mailbox`, `backup`,
/// `word_automation`); ohne gemeinsamen Rumpf laufen sie zwangsläufig
/// auseinander.
///
/// Aufteilung der Karten: [links] und [rechts] sind die beiden Spalten des
/// breiten Falls, gruppiert nach Thema. Wird es eng, laufen sie zu einer
/// Spalte zusammen — `links` zuerst. Die Grenzen dafür stehen in
/// [KartenSpalten].
class EinstellungenReiter extends StatefulWidget {
  /// Die eine Aktion des Reiters, rechts in der Kopfzeile — meist ein
  /// `SpeichernButton(kompakt: true)`. `null` lässt die Stelle leer.
  final Widget? aktion;

  /// Karten der linken bzw. oberen Spalte.
  final List<Widget> links;

  /// Karten der rechten Spalte. Leer heißt: immer einspaltig.
  final List<Widget> rechts;

  /// Reicht [KartenSpalten.breiteEinspaltig] durch — für Reiter, deren Inhalt
  /// von Breite lebt.
  final double? breiteEinspaltig;

  const EinstellungenReiter({
    super.key,
    this.aktion,
    required this.links,
    this.rechts = const [],
    this.breiteEinspaltig,
  });

  @override
  State<EinstellungenReiter> createState() => _EinstellungenReiterState();
}

class _EinstellungenReiterState extends State<EinstellungenReiter> {
  // Eigener Controller, damit die Bildlaufleiste am rechten Seitenrand sitzt
  // und nicht am Rand der zentrierten Kartenspalten.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EinstellungenAktionszeile(aktion: widget.aktion),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: KartenSpalten(
                links: widget.links,
                rechts: widget.rechts,
                breiteEinspaltig: widget.breiteEinspaltig,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
