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

  final andererMandant = Mandant(
    id: 8,
    vorname: 'Max',
    nachname: 'Mueller',
    erstelltAm: DateTime(2026, 1, 2),
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

  /// Review-Nachbesserung zu #133, Befund 2: Wurde derselbe Vorgang erneut
  /// gewählt (kein Wechsel, siehe Test oben zur Zentralruf-Antwort), aber
  /// inzwischen in Tab 1 einem **anderen** Mandanten zugeordnet, blieb
  /// `selectedMandant` bisher auf dem alten Stand stehen — der Frühausstieg
  /// emittierte nur `selectedVorgang` neu. §1.3: lieber leer als falsch.
  test(
    'derselbe Vorgang mit geändertem Mandanten lädt den neuen Mandanten nach',
    () async {
      final umgebung = WizardUmgebung(mandanten: [mandant, andererMandant]);
      await umgebung.wizard.selectVorgang(vorgang(mandantId: 7));
      expect(umgebung.wizard.state.selectedMandant, mandant);
      // Der Tippstand darf davon unberührt bleiben — er gehört zum Formular,
      // nicht zum Mandantenabgleich.
      umgebung.wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: '84/26 C03_GG-XY 123');

      await umgebung.wizard.selectVorgang(vorgang(mandantId: 8));

      expect(umgebung.wizard.state.selectedMandant, andererMandant);
      expect(umgebung.wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});
      await umgebung.schliesse();
    },
  );

  /// Die Gegenprobe: Der neue Stand trägt gar keinen Mandanten mehr — dann
  /// wird die Anzeige geleert statt den alten (jetzt falschen) zu behalten.
  test('derselbe Vorgang ohne Mandanten mehr leert die Anzeige', () async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);
    await umgebung.wizard.selectVorgang(vorgang(mandantId: 7));
    expect(umgebung.wizard.state.selectedMandant, mandant);

    await umgebung.wizard.selectVorgang(vorgang());

    expect(umgebung.wizard.state.selectedMandant, isNull);
    await umgebung.schliesse();
  });
}
