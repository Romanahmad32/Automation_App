import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/standardpositionen_entwurf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Entwurf, den `StandardpositionenEditor` an die Kopfzeile meldet
/// (§4.4) — hier ohne Widget-Baum, denn geprüft wird nur seine eigene
/// Änderungslogik: Wann meldet er sich, und wie unabhängig ist sein
/// Bestand von dem, was der Aufrufer ihm übergeben hat.
void main() {
  const mietwagen = StandardSchadensposition(
    bezeichnung: 'Mietwagenkosten',
    betrag: 412.5,
  );

  test('ein unveränderter Stand löst keine Meldung aus', () {
    final entwurf = StandardpositionenEntwurf();
    var meldungen = 0;
    entwurf.addListener(() => meldungen++);

    entwurf.uebernimm([mietwagen], beanstandet: false);
    entwurf.uebernimm(List.of([mietwagen]), beanstandet: false);

    expect(
      meldungen,
      1,
      reason:
          'die zweite Liste ist zwar eine neue Instanz, aber inhaltlich '
          'gleich — der Entwurf darf dafür nicht erneut melden',
    );
  });

  test('eine Änderung der Beanstandung meldet sich auch bei gleichen '
      'Positionen', () {
    final entwurf = StandardpositionenEntwurf();
    var meldungen = 0;
    entwurf.addListener(() => meldungen++);

    entwurf.uebernimm([mietwagen], beanstandet: false);
    entwurf.uebernimm(List.of([mietwagen]), beanstandet: true);

    expect(
      meldungen,
      2,
      reason:
          'die Beanstandung ist Teil des gemeldeten Stands, nicht nur '
          'die Positionen',
    );
  });

  test('die übernommenen Positionen lassen sich von außen nicht verändern', () {
    final entwurf = StandardpositionenEntwurf();
    final uebergeben = [mietwagen];

    entwurf.uebernimm(uebergeben, beanstandet: false);

    expect(
      () => entwurf.positionen.add(mietwagen),
      throwsUnsupportedError,
      reason:
          'der Knopf in der Kopfzeile liest davon, kein Aufrufer darf '
          'den Entwurf hinter dessen Rücken ändern',
    );

    uebergeben.add(mietwagen);

    expect(
      entwurf.positionen,
      const [mietwagen],
      reason:
          'übernommen ist eine Kopie — mutiert der Aufrufer seine eigene '
          'Liste danach weiter, darf der Entwurf davon nichts mehr merken',
    );
  });
}
