import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_feld.dart';

/// Lückenfüllung aus der Versicherer-Wissensbasis: ergänzt Versicherer-Felder,
/// die in der ausgewerteten Antwort fehlen, aus einem bekannten Registereintrag
/// desselben Versicherers — mit Herkunftshinweis je Feld, damit der Anwalt
/// erkennt, dass der Wert nicht aus dieser Antwort stammt.
class VersichererErgaenzung {
  /// Ergänzte Werte je Feld (nur Felder, die in der Antwort leer waren und im
  /// Register belegt sind).
  final Map<VorgangsdatenFeld, String> werte;

  /// Herkunftshinweis für die ergänzten Felder.
  final String hinweis;

  const VersichererErgaenzung({required this.werte, required this.hinweis});

  static const leer = VersichererErgaenzung(werte: {}, hinweis: '');

  /// Ermittelt die ergänzbaren Felder aus dem Registereintrag [bekannt]
  /// (typisch: `VersichererCubit.findeZuName(data.versichererName)`).
  /// Ohne Registereintrag oder ohne Lücken bleibt das Ergebnis [leer].
  factory VersichererErgaenzung.ermittle(
    ZentralrufReplyData data,
    Versicherer? bekannt,
  ) {
    if (bekannt == null) return leer;

    final registerWerte = <VorgangsdatenFeld, String?>{
      VorgangsdatenFeld.versichererStrasse: bekannt.strasse,
      VorgangsdatenFeld.versichererPlz: bekannt.plz,
      VorgangsdatenFeld.versichererOrt: bekannt.ort,
      VorgangsdatenFeld.versichererTelefon: bekannt.telefon,
      VorgangsdatenFeld.versichererFax: bekannt.fax,
      VorgangsdatenFeld.versichererEmail: bekannt.email,
    };

    final werte = <VorgangsdatenFeld, String>{
      for (final MapEntry(key: feld, value: wert) in registerWerte.entries)
        if ((feld.wert(data) ?? '').trim().isEmpty &&
            (wert ?? '').trim().isNotEmpty)
          feld: wert!.trim(),
    };
    if (werte.isEmpty) return leer;

    final stand = bekannt.zuletztAktualisiertAm;
    final standTeil = stand == null
        ? ''
        : ' (Stand ${stand.day.toString().padLeft(2, '0')}.'
              '${stand.month.toString().padLeft(2, '0')}.${stand.year})';
    return VersichererErgaenzung(
      werte: werte,
      hinweis: 'ergänzt aus früheren Antworten$standTeil',
    );
  }
}
