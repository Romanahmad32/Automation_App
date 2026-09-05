import 'package:flutter/material.dart';

/// Legt die Trefferliste und das Detailpanel **nebeneinander**, sobald für
/// beide genug Platz ist, und stapelt sie sonst **untereinander**.
///
/// Anlass (Issue #57): Bei „Am größten" und einem schmalen Fenster quetschte
/// die feste 360-px-Spalte der Liste das Panel auf wenige hundert Pixel —
/// Titel und Erklärtext brachen in viele kurze Zeilen, und die nicht
/// scrollbare Spalte lief unten über. Unterhalb von [mindestbreiteListe] +
/// [mindestbreitePanel] lohnt „nebeneinander" ohnehin nicht mehr: Keine der
/// beiden Spalten bliebe breit genug, um noch lesbar zu sein.
///
/// Gestapelt steht [panel] **oben**, wenn [listeLeer] gilt — die manuelle
/// Eingabe ist dann der einzige Weg zu einer Antwort und darf vorgehen; sonst
/// steht die Liste oben, weil sie der Normalfall ist (automatisch erfasste
/// Treffer).
class MailboxListUndPanel extends StatelessWidget {
  /// Feste Breite der Liste im nebeneinander-Fall — unverändert zur bisherigen
  /// Spalte in `mailbox_inbox_view.dart`.
  static const double mindestbreiteListe = 360;

  /// Ab dieser Restbreite bleibt das Panel noch lesbar (Titel/Erklärtext ohne
  /// Zeilensalat, Knopfzeile in einer Reihe).
  static const double mindestbreitePanel = 420;

  /// Höhe der Liste im gestapelten Fall. Fest statt hälftig geteilt: Die
  /// Liste zeigt bei leerem Bestand [MailboxReplyEmptyHint] — eine nicht
  /// scrollbare, fest bemessene Mitte (Icon, Text) —, die bei einer knappen
  /// Hälfte selbst überliefe. Das Panel bekommt den Rest über [Expanded]; es
  /// steckt jede noch so kleine Höhe weg, weil sein Inhalt in einem
  /// [SingleChildScrollView] liegt (`manual_reply_input.dart`).
  static const double hoeheListeGestapelt = 400;

  final Widget list;
  final Widget panel;
  final bool listeLeer;

  const MailboxListUndPanel({
    super.key,
    required this.list,
    required this.panel,
    required this.listeLeer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nebeneinander =
            constraints.maxWidth >= mindestbreiteListe + mindestbreitePanel;

        if (nebeneinander) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: mindestbreiteListe, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: panel),
            ],
          );
        }

        final listBox = SizedBox(height: hoeheListeGestapelt, child: list);
        final panelBox = Expanded(child: panel);
        return Column(
          children: listeLeer
              ? [panelBox, const Divider(height: 1), listBox]
              : [listBox, const Divider(height: 1), panelBox],
        );
      },
    );
  }
}
