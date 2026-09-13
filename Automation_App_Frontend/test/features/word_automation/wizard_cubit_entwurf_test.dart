import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Teil 2 von #37: Der angefangene Stand wird am Vorgang gesichert und beim
/// Wiedereinstieg wieder eingesetzt. Seit #133 **ohne Nachfrage** — und das
/// geht nur, weil nicht der ganze Formularstand aufgehoben wird, sondern allein
/// die Abweichungen von der Vorbelegung: Ein voller Stand fröre sie ein und
/// verdeckte eine später eintreffende Zentralruf-Antwort.
///
/// Die beiden Regeln, an denen hier alles hängt: Nichts geht verloren, und
/// nichts verdeckt den Bestand.
void main() {
  const referenz = '84/26 C03_GG-XY 123';
  const andereReferenz = '85/26 C03_GG-AB 456';

  /// Der Stand, wie er am Vorgang liegt: **nur** das abweichende Feld.
  final entwurf = VorgangEntwurf(
    gespeichertAm: DateTime(2026, 8, 30, 14, 32),
    feldWerte: const {'Versicherer': 'HUK-COBURG'},
    schadensaufstellung: const DamageListing(
      items: [DamageItem(description: 'Reparaturkosten', amount: 500)],
    ),
  );

  const vorlage = FormTemplate(
    id: 7,
    templateName: 'Anspruchsschreiben',
    fields: [],
    wordFilePathMitAuflistung: r'C:\Vorlagen\mit.docx',
  );

  const andereVorlage = FormTemplate(
    id: 8,
    templateName: 'Mahnung',
    fields: [],
    wordFilePathOhneAuflistung: r'C:\Vorlagen\ohne.docx',
  );

  Vorgang vorgang({VorgangEntwurf? mitEntwurf, String schluessel = referenz}) =>
      Vorgang.ausAnfrage(
        referenz: schluessel,
        angefragtAm: DateTime(2026, 6, 1),
      ).copyWith(entwurf: () => mitEntwurf);

  late WizardUmgebung umgebung;

  setUp(() => umgebung = WizardUmgebung());
  tearDown(() => umgebung.schliesse());

  group('Wiedereinstieg', () {
    test('ein vorhandener Stand wird still eingesetzt', () async {
      final wizard = umgebung.wizard;

      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK-COBURG'});
      expect(wizard.state.damageListing, entwurf.schadensaufstellung);
    });

    /// Der Stand trägt nur die Abweichung — die übrigen Felder holt sich das
    /// Formular jedes Mal frisch aus dem Bestand. Deshalb steht hier auch nach
    /// dem Einsetzen nur das eine Feld.
    test('eingesetzt wird nur die Abweichung', () async {
      final wizard = umgebung.wizard;

      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

      expect(wizard.state.formDataEntwurf?.keys, ['Versicherer']);
    });

    /// Ohne die erhöhte Marke bliebe die FormGroup womöglich stehen: Sie hängt
    /// an Vorlage und Vorbelegung, die einzusetzenden Werte stehen nicht im
    /// Schlüssel.
    test('das Formular wird zum Neuaufbau gezwungen', () async {
      final wizard = umgebung.wizard;
      final marke = wizard.state.aufbauMarke;

      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

      expect(wizard.state.aufbauMarke, marke + 1);
    });

    /// Der Ausflug zu einem anderen Vorgang und zurück: An jedem Vorgang steht
    /// wieder, was dort zuletzt getippt wurde.
    test('A → B → A bringt denselben Stand zurück', () async {
      final wizard = umgebung.wizard;

      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
      await wizard.selectVorgang(vorgang(schluessel: andereReferenz));
      expect(wizard.state.formDataEntwurf, isNull, reason: 'B hat keinen');

      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK-COBURG'});
      expect(wizard.state.damageListing, entwurf.schadensaufstellung);
    });

    /// Der Absprung aus Übersicht oder Vorgängen wählt denselben Vorgang noch
    /// einmal. Vorher leerte das den Tippstand — die FormGroup blieb dabei
    /// stehen, der Stand war trotzdem weg (#133).
    ///
    /// Gewählt wird hier ein **gleichwertiges, aber nicht identisches** Objekt:
    /// Genau so kommt es an. `vorgang_selector.dart` reicht die Vorgänge aus
    /// der geladenen Liste und aus dem Vorauswahl-Vorschlag durch, und nach
    /// jedem Neuladen sind das neue Instanzen.
    test('derselbe Vorgang erneut gewählt setzt nichts zurück', () async {
      final wizard = umgebung.wizard;
      final gewaehlt = vorgang(mitEntwurf: entwurf);
      await wizard.selectVorgang(gewaehlt);
      wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: referenz);

      final erneut = vorgang(mitEntwurf: entwurf);
      expect(identical(gewaehlt, erneut), isFalse, reason: 'neue Instanz');
      await wizard.selectVorgang(erneut);

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});
    });

    /// #150 Review: Der Frühausstieg griff bisher, bevor `selectedVorgang`
    /// aktualisiert wurde. Trifft eine inhaltlich neue Fassung desselben
    /// Vorgangs ein (z. B. Zentralruf-Antwort eingetroffen), muss der Wizard
    /// die frischen Daten übernehmen — aber ohne Reset.
    test(
      'derselbe Vorgang mit neuem Inhalt erneut gewählt übernimmt die Daten',
      () async {
        final wizard = umgebung.wizard;
        final erstesMal = vorgang();
        await wizard.selectVorgang(erstesMal);
        wizard.setFormDataEntwurf(const {
          'Versicherer': 'Allianz',
        }, fuerReferenz: referenz);

        final neuerStand = erstesMal.copyWith(
          gegner: 'HUK-COBURG',
          entwurf: () => entwurf,
        );
        await wizard.selectVorgang(neuerStand);

        expect(wizard.state.selectedVorgang, neuerStand);
        expect(wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});
      },
    );
  });

  group('Race beim Vorgangswechsel', () {
    /// Review-Nachbesserung zu #133, Befund 1: Der `FormWertBeobachter` des
    /// alten Formulars meldet eine ausstehende Änderung aus seinem
    /// `dispose()` heraus — das läuft manchmal erst **nach** dem Emit von
    /// [WizardCubit.selectVorgang]. Ohne den Referenzabgleich schriebe die
    /// Meldung von A die getippten Werte auf den inzwischen gewählten
    /// Vorgang B fort (`ausfuell_formular_test.dart` prüft denselben Fall am
    /// Widget entlang der Entprellung).
    test(
      'eine verspätete Meldung zur vorigen Referenz bleibt ohne Wirkung',
      () async {
        final wizard = umgebung.wizard;
        await wizard.selectVorgang(vorgang());
        await wizard.selectVorgang(vorgang(schluessel: andereReferenz));
        final standNachDemWechsel = wizard.state.formDataEntwurf;
        final schreibaufrufeNachDemWechsel = umgebung.ablage.entwuerfe.length;

        wizard.setFormDataEntwurf(const {
          'Versicherer': 'aus dem alten Formular',
        }, fuerReferenz: referenz);

        expect(wizard.state.formDataEntwurf, standNachDemWechsel);
        expect(
          umgebung.ablage.entwuerfe,
          hasLength(schreibaufrufeNachDemWechsel),
        );
      },
    );
  });

  group('Vorlagenwechsel', () {
    /// Der Stand ist nach Feldbezeichnung geschlüsselt, nicht nach Vorlage.
    /// Wer zwischen zwei Vorlagen hin- und herschaut, will sein Getipptes
    /// beim Zurückkommen wiederfinden (#133).
    test('X → Y → X lässt den Tippstand stehen', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.selectFormTemplate(vorlage);
      wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: referenz);

      wizard.selectFormTemplate(andereVorlage);
      expect(wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});

      wizard.selectFormTemplate(vorlage);

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});
    });

    /// Gemeldet wird immer die ganze gerade gezeigte Vorlage. Ein Feld, das sie
    /// nicht kennt, darf davon nicht wegfallen — sonst kostete jeder Blick in
    /// die andere Vorlage die Eingaben der einen.
    test('ein der Vorlage fremdes Feld überlebt die Meldung', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.setFormDataEntwurf(const {
        'Aktenzeichen der Gegenseite': 'XY-9',
      }, fuerReferenz: referenz);

      wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: referenz);

      expect(wizard.state.formDataEntwurf, {
        'Aktenzeichen der Gegenseite': 'XY-9',
        'Versicherer': 'Allianz',
      });
    });

    /// Die Gegenprobe: Ein Feld, das die gezeigte Vorlage **kennt**, kommt auf
    /// die Vorbelegung zurück, sobald sein Wert ihr wieder entspricht.
    test('ein Feld auf der Vorbelegung fällt wieder heraus', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.setFormDataEntwurf(
        const {'Versicherer': 'Allianz'},
        vorbelegung: const {'Versicherer': 'HUK-COBURG'},
        fuerReferenz: referenz,
      );
      expect(wizard.state.formDataEntwurf, {'Versicherer': 'Allianz'});

      wizard.setFormDataEntwurf(
        const {'Versicherer': 'HUK-COBURG'},
        vorbelegung: const {'Versicherer': 'HUK-COBURG'},
        fuerReferenz: referenz,
      );

      expect(wizard.state.formDataEntwurf, isEmpty);
    });
  });

  group('Sichern', () {
    test('gesichert wird nur, was von der Vorbelegung abweicht', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang());
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());

      wizard.setFormDataEntwurf(
        const {'Versicherer': 'Allianz', 'Schadennummer': '4711'},
        vorbelegung: const {'Schadennummer': '4711'},
        fuerReferenz: referenz,
      );

      expect(umgebung.ablage.entwuerfe.single?.feldWerte, {
        'Versicherer': 'Allianz',
      });
    });

    /// Ein leerer Entwurf wäre ein Versprechen ohne Inhalt — und der nächste
    /// Einstieg müsste ihn erst wieder wegrechnen.
    test('ohne Abweichung wird der Stand am Vorgang gelöscht', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang(mitEntwurf: entwurf));
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
      // Die Positionen des Stands mitnehmen, sonst bliebe der Entwurf ihretwegen
      // stehen — hier geht es um den Fall „gar nichts mehr da".
      wizard.setDamageListing(const DamageListing(items: []));

      wizard.setFormDataEntwurf(
        const {'Versicherer': 'HUK-COBURG'},
        vorbelegung: const {'Versicherer': 'HUK-COBURG'},
        fuerReferenz: referenz,
      );

      expect(umgebung.ablage.entwuerfe.last, isNull);
      expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf, isNull);
    });

    /// Die Meldung des Formulars ist entprellt (300 ms, `FormWertBeobachter`);
    /// hier wartet nichts mehr. Zwei Entprellungen hintereinander waren bis zu
    /// vier Sekunden, in denen der Stand nur im Speicher lag.
    test('der gemeldete Stand geht sofort hinaus', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang());
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());

      wizard.setFormDataEntwurf(const {
        'Versicherer': 'HUK',
      }, fuerReferenz: referenz);

      expect(umgebung.ablage.entwuerfe.single?.feldWerte, {
        'Versicherer': 'HUK',
      });
      expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf, isNotNull);
    });

    /// Einen Eingabeschritt zu verlassen ist der Punkt, an dem der Anwalt mit
    /// dem Bisherigen fertig ist — hier wird auch nicht auf die Entprellung des
    /// Formulars gewartet. Ohne echte Änderung seit der letzten Meldung
    /// schreibt der Schrittwechsel aber **nicht** erneut (Mangel 1, #133):
    /// Zwei gleiche Inhalte hintereinander sind ein Schreibaufruf, nicht zwei.
    test('ein Schrittwechsel sichert nur bei echter Änderung erneut', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang());
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.selectFormTemplate(vorlage);
      wizard.setFormDataEntwurf(const {
        'Versicherer': 'HUK',
      }, fuerReferenz: referenz);
      final bisher = umgebung.ablage.entwuerfe.length;

      // Unverändert seit der letzten Meldung: kein zweiter Schreibaufruf.
      wizard.goToStep(WizardStep.schadensaufstellung);
      expect(umgebung.ablage.entwuerfe, hasLength(bisher));

      // `stelleFeldWertWiederHer` ändert den Stand, ohne selbst zu sichern —
      // der nächste Schrittwechsel muss diese Lücke schließen.
      wizard.stelleFeldWertWiederHer('Versicherer', 'Allianz');
      wizard.goToStep(WizardStep.fillOut);

      expect(umgebung.ablage.entwuerfe, hasLength(bisher + 1));
      expect(umgebung.ablage.entwuerfe.last?.feldWerte, {
        'Versicherer': 'Allianz',
      });
    });

    /// Die Erzeugung schaltet auf „Begutachten" und lässt gleich darauf den
    /// Rückfluss den Entwurf am Vorgang löschen. Würde danach weiter gesichert,
    /// stünde der gerade bestätigte Stand beim nächsten Einstieg wieder im
    /// Formular — als angefangen, obwohl er längst in einem Schreiben steht.
    test('nach der Bestätigung wird nichts mehr gesichert', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang());
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.setFormData(const {'Versicherer': 'HUK'});
      final bisher = umgebung.ablage.entwuerfe.length;

      wizard.goToStep(WizardStep.review);
      wizard.uebernehmeVorgangsStand(vorgang());
      await wizard.close();

      expect(umgebung.ablage.entwuerfe, hasLength(bisher));
    });

    /// Wer wieder tippt, macht aus dem bestätigten Stand einen angefangenen.
    test('eine neue Eingabe hebt die Bestätigung auf', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang());
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      wizard.uebernehmeVorgangsStand(vorgang());

      wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: referenz);

      expect(umgebung.ablage.entwuerfe.last?.feldWerte, {
        'Versicherer': 'Allianz',
      });
    });

    test('ohne Vorgang wird kein Entwurf gehalten', () async {
      final wizard = umgebung.wizard;

      wizard.setFormDataEntwurf(const {
        'Versicherer': 'HUK',
      }, fuerReferenz: null);
      wizard.sichereEntwurfJetzt();

      expect(umgebung.ablage.entwuerfe, isEmpty);
    });

    /// `null` heißt im Wizard **noch nicht geladen**, nicht „keine": Auf null
    /// steht die Aufstellung nach jedem Vorlagenwechsel. Schriebe die nächste
    /// Sicherung sie als „keine" fort, verlöre ein Hin-und-Her zwischen zwei
    /// Vorlagen die erfassten Positionen.
    test('ein Vorlagenwechsel nimmt die Positionen nicht mit', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang(mitEntwurf: entwurf));
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

      wizard.selectFormTemplate(andereVorlage);
      expect(wizard.state.damageListing, isNull);
      wizard.setFormDataEntwurf(const {
        'Versicherer': 'Allianz',
      }, fuerReferenz: referenz);

      expect(
        umgebung.ablage.entwuerfe.last?.schadensaufstellung,
        entwurf.schadensaufstellung,
      );
    });
  });

  group('Zurücksetzen', () {
    test('löscht den Stand im Formular und am Vorgang', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang(mitEntwurf: entwurf));
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
      wizard.setDamageListing(const DamageListing(items: []));

      final bisher = wizard.setzeEingabenZurueck();

      expect(bisher, {'Versicherer': 'HUK-COBURG'});
      // Leer, nicht `null`: `null` hieße „nie getippt" und ließe den Stand am
      // Vorgang unangetastet stehen.
      expect(wizard.state.formDataEntwurf, isEmpty);
      expect(wizard.state.formData, isNull);
      expect(umgebung.ablage.entwuerfe.last, isNull);
      expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf, isNull);
    });

    test('zwingt das Formular zum Neuaufbau', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
      final marke = wizard.state.aufbauMarke;

      wizard.setzeEingabenZurueck();

      expect(wizard.state.aufbauMarke, marke + 1);
    });

    test('ohne Eingaben gibt es nichts zurückzunehmen', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());

      expect(wizard.setzeEingabenZurueck(), isNull);
    });

    /// Zurücksetzen löscht — deshalb ist es kurz zurücknehmbar (#133).
    test('„Rückgängig" setzt Formular und Ablage wieder', () async {
      await umgebung.vorgaenge.aktualisiere(vorgang(mitEntwurf: entwurf));
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
      final bisher = wizard.setzeEingabenZurueck()!;

      wizard.stelleEingabenWiederHer(bisher);

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK-COBURG'});
      expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf?.feldWerte, {
        'Versicherer': 'HUK-COBURG',
      });
    });
  });
}
