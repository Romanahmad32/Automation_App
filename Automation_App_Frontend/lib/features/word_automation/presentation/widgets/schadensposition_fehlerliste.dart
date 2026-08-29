import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:flutter/material.dart';

/// Die Beanstandungen der Schadensaufstellung über dem Knopf „Dokument
/// erstellen" — je Zeile ein fertiger Satz.
///
/// Warum gedeckelt: Die Zahl der Positionen ist nach oben offen, und die Liste
/// sitzt im **festen** Teil der Spalte, direkt über dem Knopf. Acht
/// beanstandete Zeilen drückten auf einem kleinen Fenster den `Expanded`
/// darüber auf null und den Knopf aus dem Bild — ausgerechnet den, um den es in
/// den Meldungen geht. Drei Sätze reichen zum Handeln; die Zeilen selbst sind
/// ohnehin einzeln rot markiert.
class SchadenspositionFehlerliste extends StatelessWidget {
  /// Wie viele Sätze ausgeschrieben werden, bevor gezählt wird.
  static const int hoechstens = 3;

  final List<String> meldungen;

  const SchadenspositionFehlerliste({super.key, required this.meldungen});

  @override
  Widget build(BuildContext context) {
    final gezeigt = meldungen.take(hoechstens);
    final weitere = meldungen.length - hoechstens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final meldung in gezeigt) FehlerHinweis(nachricht: meldung),
          if (weitere > 0)
            FehlerHinweis(
              nachricht: weitere == 1
                  ? 'und eine weitere Position'
                  : 'und $weitere weitere Positionen',
            ),
        ],
      ),
    );
  }
}
