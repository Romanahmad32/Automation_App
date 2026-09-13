import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter/material.dart';

/// **Der eine** Weg, von der Mandantenkarte eine Akte oder einen Fall im
/// Explorer zu öffnen (#132) — das Gegenstück zu `VorlagenDateiOeffnen` für
/// Ordner. Die Mechanik und die Test-Naht liegen in
/// [DateiOeffner.oeffneOrdner]; hier liegt, was der Anwalt erfährt, wenn es
/// nicht geht.
class AktenOrdnerOeffnen {
  const AktenOrdnerOeffnen._();

  /// Öffnet [pfad]; fehlt der Ordner, sagt eine Rückmeldung es, statt dass der
  /// Klick wortlos verpufft. Gemeldet wird [name] — der Ordnername, den der
  /// Anwalt auf der Karte sieht, nicht der Pfad dahinter.
  ///
  /// [Rueckmeldung.von] **vor** dem `await`, wie in `VorlagenDateiOeffnen`:
  /// Nach dem Öffnen kann die Karte weg sein.
  static Future<void> oeffne(
    BuildContext context, {
    required String pfad,
    required String name,
  }) async {
    final melder = Rueckmeldung.von(context);
    if (await DateiOeffner.oeffneOrdner(pfad)) return;

    melder.hinweis(
      'Der Ordner „$name" wurde nicht gefunden — umbenannt oder verschoben? '
      'Neu laden zeigt den aktuellen Stand.',
    );
  }
}
