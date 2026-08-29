import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Setzt die Anschrift des Mandanten aus den einzeln gespeicherten Stammdaten
/// zusammen — die Auflösung der Datenquelle `mandantAnschrift`.
///
/// Warum es diesen Baustein überhaupt gibt, wo doch sonst gilt „einzeln
/// gespeichert → eigene Datenquelle, Zusammensetzung → zwei Platzhalter
/// nebeneinander in der Word-Datei": Er kann etwas, was zwei Platzhalter
/// nebeneinander nicht können — **fehlende Teile weglassen.** Ohne Straße
/// hinterlassen zwei Platzhalter eine Leerstelle samt wanderndem Komma; hier
/// fällt der Teil ersatzlos raus. Gebraucht wird das im Fließtext („…,
/// {{MandantAdresse}}, mit seiner rechtlichen Interessenvertretung …").
///
/// Hieß bis zur Zusammenführung der Zuordnungslogik `MandantFeldHeuristik` und
/// enthielt zusätzlich die Stichwortliste „Straße des Mandanten" →
/// `strasseHausnummer`. Die ist in `FeldDatenquelleErkennung` aufgegangen,
/// damit es nur noch eine Wortliste gibt — geblieben ist das Zusammensetzen.
class MandantAnschrift {
  const MandantAnschrift._();

  /// Anschrift „Name, Straße, PLZ Ort" aus den Registerdaten (null, wenn kein
  /// Mandant verknüpft ist oder alle Teile leer sind).
  static String? aus(Mandant? mandant) {
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
