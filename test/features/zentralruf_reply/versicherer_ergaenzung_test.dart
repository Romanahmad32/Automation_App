import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/versicherer_ergaenzung.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_feld.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bekannt = Versicherer(
    id: 1,
    name: 'HUK-COBURG',
    strasse: 'Bahnhofsplatz 1',
    plz: '96444',
    ort: 'Coburg',
    email: 'schaden@huk.de',
  );

  test('ergänzt nur Felder, die in der Antwort fehlen', () {
    const data = ZentralrufReplyData(
      versichererName: 'HUK-COBURG',
      versichererOrt: 'Coburg', // schon vorhanden — bleibt außen vor
    );

    final ergaenzung = VersichererErgaenzung.ermittle(data, bekannt);

    expect(ergaenzung.werte, {
      VorgangsdatenFeld.versichererStrasse: 'Bahnhofsplatz 1',
      VorgangsdatenFeld.versichererPlz: '96444',
      VorgangsdatenFeld.versichererEmail: 'schaden@huk.de',
    });
    expect(ergaenzung.hinweis, contains('ergänzt aus früheren Antworten'));
  });

  test('nennt den Stand des Registereintrags im Herkunftshinweis', () {
    final mitStand = Versicherer(
      id: 1,
      name: 'HUK-COBURG',
      email: 'schaden@huk.de',
      zuletztAktualisiertAm: DateTime(2026, 6, 12),
    );

    final ergaenzung = VersichererErgaenzung.ermittle(
      const ZentralrufReplyData(versichererName: 'HUK-COBURG'),
      mitStand,
    );

    expect(ergaenzung.hinweis, contains('12.06.2026'));
  });

  test('ohne Registereintrag oder ohne Lücken bleibt das Ergebnis leer', () {
    expect(
      VersichererErgaenzung.ermittle(const ZentralrufReplyData(), null),
      VersichererErgaenzung.leer,
    );

    const vollstaendig = ZentralrufReplyData(
      versichererName: 'HUK-COBURG',
      versichererStrasse: 'Bahnhofsplatz 1',
      versichererPlz: '96444',
      versichererOrt: 'Coburg',
      versichererTelefon: '09561 960',
      versichererFax: '09561 961',
      versichererEmail: 'schaden@huk.de',
    );
    expect(
      VersichererErgaenzung.ermittle(vollstaendig, bekannt).werte,
      isEmpty,
    );
  });
}
