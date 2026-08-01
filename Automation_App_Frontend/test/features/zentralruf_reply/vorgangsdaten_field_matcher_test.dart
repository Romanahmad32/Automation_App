import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/domain/services/vorgangsdaten_field_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Werte aus "Beispiele/Anwortemail von Zentralruf.txt".
  const data = ZentralrufReplyData(
    referenz: '84/26 C03_GG-XY 123',
    anfrageDatum: '08.04.2026',
    kennzeichen: 'GG XY 123',
    unfallDatum: '09.03.2026',
    versichererName: 'HUK-COBURG',
    versichererStrasse: 'Lyoner Str. 10',
    versichererPlz: '60524',
    versichererOrt: 'Frankfurt',
    versichererTelefon: '0800/248544533',
    versichererFax: '0800-2485329',
    versichererEmail: 'info@huk-coburg.de',
    versicherungsscheinNr: '999/123456-X',
    versicherungsbeginn: '07.10.2015',
  );

  test('ordnet typische Vorlagenfelder den Antwortdaten zu', () {
    final result = VorgangsdatenFieldMatcher.matchFields([
      'Versicherungsschein-Nr.',
      'Unfalldatum',
      'Kennzeichen des Unfallgegners',
      'Gegnerische Versicherung',
      'E-Mail der Versicherung',
      'Aktenzeichen',
    ], data);

    expect(result['Versicherungsschein-Nr.'], '999/123456-X');
    expect(result['Unfalldatum'], '09.03.2026');
    expect(result['Kennzeichen des Unfallgegners'], 'GG XY 123');
    expect(result['Gegnerische Versicherung'], 'HUK-COBURG');
    expect(result['E-Mail der Versicherung'], 'info@huk-coburg.de');
    expect(result['Aktenzeichen'], '84/26 C03_GG-XY 123');
  });

  test('befüllt Adressteile des Versicherers', () {
    final result = VorgangsdatenFieldMatcher.matchFields([
      'Straße der Versicherung',
      'PLZ Versicherer',
      'Ort der Versicherung',
      'Anschrift der Versicherung',
    ], data);

    expect(result['Straße der Versicherung'], 'Lyoner Str. 10');
    expect(result['PLZ Versicherer'], '60524');
    expect(result['Ort der Versicherung'], 'Frankfurt');
    expect(
      result['Anschrift der Versicherung'],
      'HUK-COBURG, Lyoner Str. 10, 60524 Frankfurt',
    );
  });

  test('lässt Mandantenfelder und unbekannte Felder leer', () {
    final result = VorgangsdatenFieldMatcher.matchFields([
      'Name des Mandanten',
      'Kennzeichen Mandant',
      'Straße des Geschädigten',
      'Notiz',
      'Frist',
    ], data);

    expect(result, isEmpty);
  });

  test('lässt Felder leer, deren Wert in der Antwort fehlt', () {
    const unvollstaendig = ZentralrufReplyData(kennzeichen: 'GG XY 123');

    final result = VorgangsdatenFieldMatcher.matchFields([
      'Versicherungsschein-Nr.',
      'Kennzeichen',
    ], unvollstaendig);

    expect(result, {'Kennzeichen': 'GG XY 123'});
  });
}
