import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

void main() {
  final mandant = Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    erstelltAm: DateTime(2026, 1, 1),
  );

  Vorgang vorgang({int? mandantId}) => Vorgang.ausAnfrage(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    mandantId: mandantId,
    mandantName: 'Erika Mustermann',
  );

  test('selectVorgang löst den verknüpften Mandanten auf', () async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);

    await umgebung.wizard.selectVorgang(vorgang(mandantId: 7));

    expect(
      umgebung.wizard.state.selectedVorgang?.referenz,
      '84/26 C03_GG-XY 123',
    );
    expect(umgebung.wizard.state.selectedMandant, mandant);
    await umgebung.schliesse();
  });

  test('selectVorgang ohne mandantId lädt das Register nicht', () async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);

    await umgebung.wizard.selectVorgang(vorgang());

    expect(umgebung.wizard.state.selectedVorgang, isNotNull);
    expect(umgebung.wizard.state.selectedMandant, isNull);
    expect(umgebung.getMandanten.aufrufe, 0);
    await umgebung.schliesse();
  });

  test('selectVorgang(null) hebt die Auswahl auf', () async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);

    await umgebung.wizard.selectVorgang(vorgang(mandantId: 7));
    await umgebung.wizard.selectVorgang(null);

    expect(umgebung.wizard.state.selectedVorgang, isNull);
    expect(umgebung.wizard.state.selectedMandant, isNull);
    await umgebung.schliesse();
  });

  /// Die Aufstellung gehört zum Vorgang. Blieb sie beim Umwählen stehen, zeigte
  /// der nächste Vorgang die Positionen des vorigen — und weil der Listener des
  /// Schadensaufstellungs-Schritts nur bei `damageListing == null` greift, lud
  /// er die eigene gespeicherte Aufstellung nie nach. Eine stehengebliebene
  /// Beanstandung sperrte obendrein den Knopf im falschen Vorgang.
  test('selectVorgang verwirft Aufstellung und Beanstandungen', () async {
    final umgebung = WizardUmgebung();

    umgebung.wizard.setDamageListing(
      const DamageListing(
        items: [DamageItem(description: 'Reparaturkosten', amount: 500)],
      ),
      fehler: const [
        'Position 2 (ohne Bezeichnung): Betrag darf nicht negativ sein',
      ],
    );
    await umgebung.wizard.selectVorgang(vorgang());

    expect(umgebung.wizard.state.damageListing, isNull);
    expect(umgebung.wizard.state.schadenspositionFehler, isEmpty);
    expect(umgebung.wizard.state.schadensaufstellungIstErzeugbar, isFalse);
    await umgebung.schliesse();
  });
}
