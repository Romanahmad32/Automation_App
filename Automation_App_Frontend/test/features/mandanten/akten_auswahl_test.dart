import 'package:automation_app/features/mandanten/domain/entities/akten_auswahl_eintrag.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/services/akten_auswahl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Die Liste in „Akte zuordnen" an der Mandantenkarte (#132): welche Ordner
/// darin stehen, in welcher Reihenfolge, und welche sich nicht wählen lassen.
void main() {
  final mueller = mandant(
    1,
    'Müller',
    vorname: 'Max',
    ordner: ['VUnfallursache Müller'],
  );

  List<AktenAuswahlEintrag> auswahl({
    List<String> zugeordnet = const [],
    List<String> vermerkt = const [],
  }) => AktenAuswahl.fuer(
    mandant: mueller,
    akten: [
      akte('Fremd Müller'),
      akte('Strafsache Schulz'),
      akte('Beiseite'),
      akte('VUnfallursache Müller'),
      akte('Bußgeldsache Müller'),
      akte('VUnfallursache Albrecht'),
    ],
    zugeordnet: OrdnernamenMenge(['VUnfallursache Müller', ...zugeordnet]),
    ohneMandantenbezug: OrdnernamenMenge(vermerkt),
  );

  List<String> namen(List<AktenAuswahlEintrag> eintraege) => [
    for (final e in eintraege) e.akte.ordnername,
  ];

  test('Namensvorschläge vorn, dann offene, vermerkte, zuletzt fremde', () {
    final eintraege = auswahl(
      zugeordnet: ['fremd müller'],
      vermerkt: ['Beiseite'],
    );

    expect(namen(eintraege), [
      'Bußgeldsache Müller',
      'Strafsache Schulz',
      'VUnfallursache Albrecht',
      'Beiseite',
      'Fremd Müller',
    ]);
    expect(
      [for (final e in eintraege) e.art],
      [
        AktenAuswahlArt.namensvorschlag,
        AktenAuswahlArt.offen,
        AktenAuswahlArt.offen,
        AktenAuswahlArt.ohneMandantenbezug,
        AktenAuswahlArt.fremdZugeordnet,
      ],
    );
  });

  test('die eigenen Ordner stehen nicht zur Wahl', () {
    expect(namen(auswahl()), isNot(contains('VUnfallursache Müller')));
  });

  // Der Name passt, aber der Ordner gehört schon jemandem: Sperre geht vor
  // Vorschlag — sonst stünde ganz oben ein Ordner, der sich nicht wählen lässt.
  test('ein fremd zugeordneter Ordner ist gesperrt, auch in anderer '
      'Schreibweise und auch wenn der Name passt', () {
    final eintraege = auswahl(zugeordnet: ['bußgeldsache MÜLLER']);
    final bussgeld = eintraege.firstWhere(
      (e) => e.akte.ordnername == 'Bußgeldsache Müller',
    );

    expect(bussgeld.art, AktenAuswahlArt.fremdZugeordnet);
    expect(bussgeld.waehlbar, isFalse);
    expect(eintraege.last, bussgeld);
  });

  test('ein vermerkter Ordner, der zum Namen passt, nennt den Vermerk', () {
    final eintraege = auswahl(vermerkt: ['Bußgeldsache Müller']);

    expect(eintraege.first.akte.ordnername, 'Bußgeldsache Müller');
    expect(eintraege.first.art, AktenAuswahlArt.namensvorschlag);
    expect(eintraege.first.vermerkt, isTrue);
  });

  group('passtZumNamen', () {
    test('der Nachname entscheidet, ohne Rücksicht auf die Schreibweise', () {
      expect(
        AktenAuswahl.passtZumNamen('VUnfallursache müller', mueller),
        true,
      );
      expect(AktenAuswahl.passtZumNamen('Müller', mueller), true);
      expect(
        AktenAuswahl.passtZumNamen('VUnfallursache Meier', mueller),
        false,
      );
    });

    test('nennen beide einen Vornamen, muss auch der passen', () {
      expect(AktenAuswahl.passtZumNamen('Max Müller', mueller), true);
      expect(AktenAuswahl.passtZumNamen('Erika Müller', mueller), false);
    });

    test('ohne Nachnamen am Mandanten gibt es keinen Vorschlag', () {
      expect(AktenAuswahl.passtZumNamen('Irgendwas', mandant(2, '')), false);
    });
  });

  test('die Suche filtert in der Reihenfolge der Auswahl', () {
    final eintraege = auswahl(zugeordnet: ['Fremd Müller']);

    expect(namen(AktenAuswahl.filtere(eintraege, 'MÜLLER')), [
      'Bußgeldsache Müller',
      'Fremd Müller',
    ]);
    expect(AktenAuswahl.filtere(eintraege, '  '), eintraege);
  });
}
