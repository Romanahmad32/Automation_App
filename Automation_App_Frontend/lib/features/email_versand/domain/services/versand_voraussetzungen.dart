import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_pruefung.dart';

/// Prüft, ob die Mail hinausgehen kann, und sagt je Feld, was fehlt (§4.7).
///
/// Beim Testen fiel der Fall auf, in dem eine Prüfung am teuersten fehlt: Der
/// Anwalt tippt die Adresse ein und drückt Senden, ohne sie mit der
/// Eingabetaste übernommen zu haben. Das Feld sieht ausgefüllt aus, der Entwurf
/// hat aber keinen Empfänger — und nichts auf dem Schirm erklärt den
/// Unterschied. Genau dieser Fall steht deshalb an der Empfängerzeile.
class VersandVoraussetzungen {
  const VersandVoraussetzungen._();

  /// [offenAn] und [offenKopie] sind Texte, die in einer Empfängerzeile stehen,
  /// aber noch nicht übernommen wurden.
  ///
  /// [gesamtBytes] ist die Nachricht mit Anhängen und Signaturbildern,
  /// [maxBytes] die Grenze des Postfachs (null = unbekannt). Die Grenze erst
  /// beim Senden zu nennen, hieße sie nach dem einen unumkehrbaren Klick zu
  /// nennen — der Server der Gegenseite weist die Mail dann ab, und der Anwalt
  /// hat einen Fehler auf Englisch statt einer Zahl vor sich.
  static VersandPruefung pruefe({
    required EmailEntwurf entwurf,
    String offenAn = '',
    String offenKopie = '',
    int gesamtBytes = 0,
    int? maxBytes,
  }) {
    return VersandPruefung(
      anFehler:
          _nichtUebernommen(offenAn) ??
          (entwurf.an.isEmpty
              ? 'Ohne Empfänger geht keine Mail hinaus.'
              : null),
      kopieFehler: _nichtUebernommen(offenKopie),
      betreffFehler: entwurf.betreff.trim().isEmpty
          ? 'Ohne Betreff geht keine Mail hinaus.'
          : null,
      groesseFehler: maxBytes != null && gesamtBytes > maxBytes
          ? 'Die Nachricht ist mit ${_mb(gesamtBytes)} MB zu groß — die Grenze '
                'liegt bei ${_mb(maxBytes)} MB. Weniger anhängen, die Dateien '
                'verkleinern oder ein Bild aus der Signatur weglassen.'
          : null,
    );
  }

  /// Eine eingetippte, aber nicht übernommene Adresse. Sie ginge beim Senden
  /// verloren, ohne dass es jemand merkt — deshalb hält sie den Versand auf.
  static String? _nichtUebernommen(String eingabe) {
    final text = eingabe.trim();
    if (text.isEmpty) return null;
    return 'Die Adresse „$text" ist noch nicht übernommen — mit der '
        'Eingabetaste oder dem Pluszeichen hinzufügen.';
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
