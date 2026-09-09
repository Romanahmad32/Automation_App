import 'package:automation_app/features/vorgaenge/domain/entities/register_nummern_stand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson liest den Nummernstand aus dem Vertrag (§6.3)', () {
    final stand = RegisterNummernStand.fromJson(const {
      'jahr': '2026',
      'hoechsteNummer': 6,
      'naechsteNummer': 7,
      'belegte': [1, 4, 5, 6],
    });

    expect(stand.jahr, '2026');
    expect(stand.hoechsteNummer, 6);
    expect(stand.naechsteNummer, 7);
    expect(stand.belegte, [1, 4, 5, 6]);
  });

  test('istBelegt meldet nur Nummern aus dem Bestand', () {
    const stand = RegisterNummernStand(
      jahr: '2026',
      hoechsteNummer: 6,
      naechsteNummer: 7,
      belegte: [1, 4, 5, 6],
    );

    expect(stand.istBelegt(5), isTrue);
    expect(stand.istBelegt(2), isFalse);
    expect(stand.istBelegt(7), isFalse);
  });
}
