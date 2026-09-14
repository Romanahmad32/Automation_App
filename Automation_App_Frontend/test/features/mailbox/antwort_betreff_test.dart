import 'package:automation_app/features/mailbox/presentation/utils/antwort_betreff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stellt "AW: " vor einen Betreff ohne Kürzel', () {
    expect(antwortBetreff('Unfall vom 12.03.'), 'AW: Unfall vom 12.03.');
  });

  test('verdoppelt ein vorhandenes "AW:" nicht', () {
    expect(antwortBetreff('AW: Unfall vom 12.03.'), 'AW: Unfall vom 12.03.');
  });

  test('verdoppelt ein vorhandenes "Re:" nicht', () {
    expect(
      antwortBetreff('Re: Schadensache Müller'),
      'Re: Schadensache Müller',
    );
  });

  test('erkennt "RE:" und "Aw:" ohne Rücksicht auf Groß-/Kleinschreibung', () {
    expect(antwortBetreff('RE: Ihr Zeichen 84/26'), 'RE: Ihr Zeichen 84/26');
    expect(antwortBetreff('Aw: Rückfrage'), 'Aw: Rückfrage');
  });

  test('trimmt Leerraum, bevor sie prüft und voranstellt', () {
    expect(antwortBetreff('  Unfall vom 12.03.  '), 'AW: Unfall vom 12.03.');
    expect(
      antwortBetreff('  re: schon beantwortet  '),
      're: schon beantwortet',
    );
  });
}
