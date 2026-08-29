import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Setzt die Anschrift des Mandanten aus den einzeln gespeicherten Stammdaten
/// zusammen — für die Datenquelle `mandantAnschrift`.
///
/// Der Rest dieser Klasse (die Stichwort-Zuordnung „Straße des Mandanten" →
/// `strasseHausnummer`) ist in `FeldDatenquelleErkennung` aufgegangen, damit es
/// nur noch eine Wortliste gibt. Geblieben ist genau das, was ein Feld allein
/// nicht kann: **fehlende Teile weglassen.** Zwei Platzhalter nebeneinander in
/// der Word-Datei hinterlassen bei fehlender Straße eine Leerstelle und ein
/// wanderndes Komma; hier fällt der Teil ersatzlos raus.
class MandantFeldHeuristik {
  const MandantFeldHeuristik._();

  /// Anschrift „Name, Straße, PLZ Ort" aus den Registerdaten (null, wenn kein
  /// Mandant verknüpft ist oder alle Teile leer sind).
  static String? anschrift(Mandant? mandant) {
    if (mandant == null) return null;
    final parts = [
      mandant.anzeigename,
      mandant.strasseHausnummer,
      [
        mandant.postleitzahl,
        mandant.ort,
      ].where((part) => part.trim().isNotEmpty).join(' '),
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
