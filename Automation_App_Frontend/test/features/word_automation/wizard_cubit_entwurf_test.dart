import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Teil 2 von #37: Der angefangene Stand wird am Vorgang gesichert und beim
/// Wiedereinstieg **angeboten**. Die beiden Regeln, an denen alles hängt:
/// nichts wird still eingesetzt, und nichts wird still überschrieben.
void main() {
  const referenz = '84/26 C03_GG-XY 123';

  final entwurf = VorgangEntwurf(
    gespeichertAm: DateTime(2026, 8, 30, 14, 32),
    feldWerte: const {'Versicherer': 'HUK-COBURG'},
    schadensaufstellung: const DamageListing(
      items: [DamageItem(description: 'Reparaturkosten', amount: 500)],
    ),
  );

  Vorgang vorgang({VorgangEntwurf? mitEntwurf}) => Vorgang.ausAnfrage(
    referenz: referenz,
    angefragtAm: DateTime(2026, 6, 1),
  ).copyWith(entwurf: () => mitEntwurf);

  late WizardUmgebung umgebung;

  setUp(() => umgebung = WizardUmgebung());
  tearDown(() => umgebung.schliesse());

  test('ein vorhandener Entwurf wird angeboten, nicht eingesetzt', () async {
    final wizard = umgebung.wizard;

    await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

    expect(wizard.state.entwurfAngebot, entwurf);
    expect(wizard.state.formDataEntwurf, isNull);
    expect(wizard.state.damageListing, isNull);
  });

  test('„Weiterarbeiten" setzt den Stand ein und baut neu auf', () async {
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));
    final marke = wizard.state.aufbauMarke;

    wizard.uebernimmEntwurf();

    expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK-COBURG'});
    expect(wizard.state.damageListing, entwurf.schadensaufstellung);
    expect(wizard.state.entwurfAngebot, isNull);
    // Ohne die erhöhte Marke bliebe die FormGroup stehen: Vorlage und
    // Vorbelegung sind unverändert, nur die einzusetzenden Werte nicht.
    expect(wizard.state.aufbauMarke, marke + 1);
  });

  test('„Verwerfen" räumt das Angebot auch am Vorgang weg', () async {
    await umgebung.vorgaenge.aktualisiere(vorgang(mitEntwurf: entwurf));
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

    wizard.verwirfEntwurf();
    await Future<void>.delayed(Duration.zero);

    expect(wizard.state.entwurfAngebot, isNull);
    expect(umgebung.ablage.entwuerfe, [null]);
    expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf, isNull);
  });

  test('der Tippstand landet entprellt am Vorgang', () async {
    await umgebung.vorgaenge.aktualisiere(vorgang());
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang());

    wizard.setFormDataEntwurf(const {'Versicherer': 'HUK'});
    expect(umgebung.ablage.entwuerfe, isEmpty, reason: 'nicht sofort');

    await Future<void>.delayed(
      WizardCubit.entwurfVerzoegerung + const Duration(milliseconds: 50),
    );

    expect(umgebung.ablage.entwuerfe.single?.feldWerte, {'Versicherer': 'HUK'});
    expect(umgebung.vorgaenge.findeZuReferenz(referenz)?.entwurf, isNotNull);
  });

  test('ein Schrittwechsel sichert sofort', () async {
    await umgebung.vorgaenge.aktualisiere(vorgang());
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang());
    wizard.selectFormTemplate(
      const FormTemplate(
        id: 1,
        templateName: 'Anspruchsschreiben',
        fields: [],
        wordFilePathMitAuflistung: r'C:\Vorlagen\mit.docx',
      ),
    );
    wizard.setFormData(const {'Versicherer': 'HUK'});

    wizard.goToStep(WizardStep.schadensaufstellung);

    expect(umgebung.ablage.entwuerfe.single?.feldWerte, {'Versicherer': 'HUK'});
  });

  /// Die Erzeugung schaltet auf „Begutachten" und lässt gleich darauf den
  /// Rückfluss den Entwurf am Vorgang löschen. Würde hier weiter gesichert,
  /// stünde der gerade bestätigte Stand als Angebot wieder da — und der Anwalt
  /// bekäme beim nächsten Einstieg eine Frage gestellt, die keine ist.
  test('nach der Bestätigung wird nichts mehr gesichert', () async {
    await umgebung.vorgaenge.aktualisiere(vorgang());
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang());
    wizard.setFormData(const {'Versicherer': 'HUK'});

    wizard.goToStep(WizardStep.review);
    wizard.uebernehmeVorgangsStand(vorgang());
    await wizard.close();

    expect(umgebung.ablage.entwuerfe, isEmpty);
  });

  test('ohne Vorgang wird kein Entwurf gehalten', () async {
    final wizard = umgebung.wizard;

    wizard.setFormDataEntwurf(const {'Versicherer': 'HUK'});
    wizard.sichereEntwurfJetzt();

    expect(umgebung.ablage.entwuerfe, isEmpty);
  });

  test('ein Vorgangswechsel nimmt das Angebot des vorigen mit', () async {
    final wizard = umgebung.wizard;
    await wizard.selectVorgang(vorgang(mitEntwurf: entwurf));

    await wizard.selectVorgang(null);

    expect(wizard.state.entwurfAngebot, isNull);
  });
}
