import 'dart:io';

/// Was an die Mail gehört: [vorauswahl] hängt von vornherein dran,
/// [ausDerAkte] steht im Dialog zum Anklicken bereit.
typedef MailAnhaenge = ({List<String> vorauswahl, List<String> ausDerAkte});

/// Stellt die Anhänge zum abgelegten Schreiben zusammen (§4.7).
///
/// Vorausgewählt ist die **PDF-Fassung** — die verbindliche Form, die nach
/// außen geht; die Word-Datei ist die Arbeitsfassung und hat bei der
/// gegnerischen Versicherung nichts verloren. Liegt kein PDF in der Akte
/// (Ablage „nur Word"), hängt eben das, was da ist.
///
/// Alles Übrige aus dem Fall-Ordner — Fotos, Gutachten, Rechnungen — wird
/// angeboten, aber nicht angehängt: Was mitgeht, entscheidet der Anwalt.
class MailAnhangAuswahl {
  const MailAnhangAuswahl._();

  static MailAnhaenge zu(String? dokumentPfad) {
    final pfad = dokumentPfad?.trim() ?? '';
    if (pfad.isEmpty) return (vorauswahl: const [], ausDerAkte: const []);

    final imOrdner = _dateienNeben(pfad);
    final pdf = _pdfFassung(pfad, imOrdner);
    final vorauswahl = pdf ?? (File(pfad).existsSync() ? pfad : null);

    return (
      vorauswahl: vorauswahl == null ? const [] : [vorauswahl],
      ausDerAkte: imOrdner.where((datei) => datei != vorauswahl).toList(),
    );
  }

  static List<String> _dateienNeben(String pfad) {
    final ordner = Directory(_ordnerVon(pfad));
    if (!ordner.existsSync()) return const [];

    final dateien = <String>[];
    for (final eintrag in ordner.listSync(followLinks: false)) {
      if (eintrag is File && !_istArbeitsdatei(eintrag.path)) {
        dateien.add(eintrag.path);
      }
    }
    return dateien..sort();
  }

  /// Die PDF-Fassung desselben Schreibens: gleicher Name, andere Endung.
  static String? _pdfFassung(String dokumentPfad, List<String> imOrdner) {
    if (dokumentPfad.toLowerCase().endsWith('.pdf')) return dokumentPfad;

    final ohneEndung = _ohneEndung(dokumentPfad).toLowerCase();
    for (final datei in imOrdner) {
      if (datei.toLowerCase().endsWith('.pdf') &&
          _ohneEndung(datei).toLowerCase() == ohneEndung) {
        return datei;
      }
    }
    return null;
  }

  /// Sperrdateien, die Word neben ein geöffnetes Dokument legt („~$Brief.docx").
  /// Die anzubieten wäre nur verwirrend.
  static bool _istArbeitsdatei(String pfad) =>
      pfad.split(RegExp(r'[\\/]')).last.startsWith(r'~$');

  static String _ordnerVon(String pfad) {
    final trenner = _letzterTrenner(pfad);
    return trenner <= 0 ? pfad : pfad.substring(0, trenner);
  }

  static String _ohneEndung(String pfad) {
    final punkt = pfad.lastIndexOf('.');
    return punkt > _letzterTrenner(pfad) ? pfad.substring(0, punkt) : pfad;
  }

  /// Letzter Verzeichnistrenner, egal welcher. **Nicht** ueber
  /// `lastIndexOf(RegExp(...))` — das liefert in Dart immer -1; `lastIndexOf`
  /// sucht nur nach Zeichenketten rueckwaerts, ein Muster findet es dort nie.
  static int _letzterTrenner(String pfad) {
    final backslash = pfad.lastIndexOf('\\');
    final slash = pfad.lastIndexOf('/');
    return backslash > slash ? backslash : slash;
  }
}
