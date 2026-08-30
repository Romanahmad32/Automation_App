import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Teil 3 von #37 — das Übel an der Wurzel: Die Feldeinstellung lässt sich aus
/// dem Ausfüllschritt heraus ändern, ohne die Seite zu verlassen. Damit das
/// mehr ist als eine Abkürzung, muss der Eingabestand die Änderung überstehen —
/// auch eine Umbenennung, unter der der eingetippte Wert sonst verschwände.
void main() {
  FieldData feld(
    String label, {
    bool required = true,
    InputType typ = InputType.text,
    FeldDatenquelle quelle = FeldDatenquelle.keine,
  }) => FieldData(
    order: 0,
    label: label,
    required: required,
    inputType: typ,
    datenquelle: quelle,
  );

  FormTemplate vorlage(List<FieldData> felder) => FormTemplate(
    id: 1,
    templateName: 'Anspruchsschreiben',
    fields: felder,
    wordFilePathOhneAuflistung: r'C:\Vorlagen\ohne.docx',
  );

  late WizardUmgebung umgebung;

  setUp(() => umgebung = WizardUmgebung());
  tearDown(() => umgebung.schliesse());

  test('die geänderte Einstellung geht an die Vorlage', () async {
    final wizard = umgebung.wizard;
    final alt = feld('Versicherer');
    wizard.selectFormTemplate(vorlage([alt, feld('Kennzeichen')]));

    final aenderung = await wizard.aktualisiereFeld(
      alt,
      feld(
        'Versicherer',
        required: false,
        quelle: FeldDatenquelle.versichererName,
      ),
    );

    expect(aenderung.gespeichert, isTrue);
    final hinaus = umgebung.updateFormTemplate.gespeicherte.single;
    expect(hinaus.id, 1);
    expect(hinaus.fields.map((f) => f.label), ['Versicherer', 'Kennzeichen']);
    expect(hinaus.fields.first.required, isFalse);
    expect(hinaus.fields.first.datenquelle, FeldDatenquelle.versichererName);
    // Der Pfad hängt nicht am Feld und darf beim Speichern nicht abhandenkommen.
    expect(hinaus.wordFilePathOhneAuflistung, r'C:\Vorlagen\ohne.docx');
    expect(wizard.state.selectedFormTemplate, hinaus);
  });

  /// Der Kern: `formData` und `formDataEntwurf` sind nach Feldnamen
  /// geschlüsselt. Ohne Umschlüsselung stünde der Wert unter einem Namen, den
  /// die Vorlage nicht mehr kennt — und das Formular startete leer, also genau
  /// der Verlust, den #37 abstellt.
  test('ein umbenanntes Feld nimmt seinen Wert mit', () async {
    final wizard = umgebung.wizard;
    final alt = feld('Versicherer');
    wizard.selectFormTemplate(vorlage([alt, feld('Kennzeichen')]));
    wizard.setFormData(const {
      'Versicherer': 'HUK-COBURG',
      'Kennzeichen': 'HG-E 1427',
    });

    await wizard.aktualisiereFeld(alt, feld('Versicherung des Gegners'));

    const erwartet = {
      'Kennzeichen': 'HG-E 1427',
      'Versicherung des Gegners': 'HUK-COBURG',
    };
    expect(wizard.state.formData, erwartet);
    expect(wizard.state.formDataEntwurf, erwartet);
  });

  /// Der Beobachter meldet auch leere Felder mit, und im Formular gewinnt der
  /// erfasste Stand über die Vorbelegung. Bliebe der leere Eintrag stehen, sähe
  /// der Anwalt von der gerade gewählten Datenquelle nichts — der Dialog wirkte
  /// wirkungslos.
  test(
    'ein leerer Wert fällt weg, statt die Vorbelegung zu schlagen',
    () async {
      final wizard = umgebung.wizard;
      final alt = feld('Versicherer');
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': '   '});

      await wizard.aktualisiereFeld(
        alt,
        feld('Versicherer', quelle: FeldDatenquelle.versichererName),
      );

      expect(wizard.state.formDataEntwurf, isEmpty);
    },
  );

  test('die anderen Felder behalten ihren Stand', () async {
    final wizard = umgebung.wizard;
    final alt = feld('Versicherer');
    wizard.selectFormTemplate(vorlage([alt, feld('Kennzeichen')]));
    wizard.setFormDataEntwurf(const {'Kennzeichen': 'HG-E 1427'});

    await wizard.aktualisiereFeld(
      alt,
      feld('Versicherer', typ: InputType.date),
    );

    expect(wizard.state.formDataEntwurf, {'Kennzeichen': 'HG-E 1427'});
    expect(
      wizard.state.selectedFormTemplate?.fields.first.inputType,
      InputType.date,
    );
  });

  /// Kommt der Dienst nicht an, bleibt der Wizard auf dem Stand des Bestands.
  /// Sonst zeigte das Formular eine Einstellung, die die Vorlage nicht hat —
  /// und beim nächsten Laden der Liste wäre sie wieder weg.
  test('schlägt das Speichern fehl, bleibt alles wie es war', () async {
    final wizard = umgebung.wizard;
    umgebung.updateFormTemplate.schlaegtFehl = true;
    final alt = feld('Versicherer');
    final bestand = vorlage([alt]);
    wizard.selectFormTemplate(bestand);
    wizard.setFormData(const {'Versicherer': 'HUK-COBURG'});

    final aenderung = await wizard.aktualisiereFeld(
      alt,
      feld('Versicherung des Gegners'),
    );

    expect(aenderung.gespeichert, isFalse);
    expect(wizard.state.selectedFormTemplate, bestand);
    expect(wizard.state.formData, {'Versicherer': 'HUK-COBURG'});
  });

  test('ohne gewählte Vorlage geht nichts hinaus', () async {
    final wizard = umgebung.wizard;

    final aenderung = await wizard.aktualisiereFeld(
      feld('Versicherer'),
      feld('Versicherung'),
    );

    expect(aenderung.gespeichert, isFalse);
    expect(umgebung.updateFormTemplate.gespeicherte, isEmpty);
  });

  /// Der Nachtrag aus der Erprobung: Nach dem Wechsel der Datenquelle gab es
  /// keinen Weg mehr, das Feld aus den Vorgangsdaten zu füllen. Der erfasste
  /// Stand beschattet die Vorbelegung dauerhaft — er wird deshalb für genau
  /// dieses Feld beiseitegeräumt.
  group('die neue Datenquelle füllt das Feld neu', () {
    const antwort = ZentralrufReplyData(
      referenz: '84/26 C03_GG-XY 123',
      versichererName: 'HUK-COBURG',
    );

    Vorgang vorgang({ZentralrufReplyData? mitAntwort = antwort}) => Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 6, 1),
      antwort: mitAntwort,
    );

    test('der getippte Wert weicht der Vorbelegung und wird angeboten', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      final alt = feld('Versicherer');
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': 'von Hand getippt'});
      final marke = wizard.state.aufbauMarke;

      final aenderung = await wizard.aktualisiereFeld(
        alt,
        feld('Versicherer', quelle: FeldDatenquelle.versichererName),
      );

      expect(aenderung.verdraengterWert, 'von Hand getippt');
      // Weg aus dem erfassten Stand: Nur so gewinnt die Vorbelegung im Formular.
      expect(wizard.state.formDataEntwurf, isEmpty);
      // Und der Neuaufbau, weil der erfasste Stand nicht im Schlüssel steht.
      expect(wizard.state.aufbauMarke, marke + 1);
    });

    /// Sonst nähme der Dialog dem Anwalt die Eingabe weg und setzte nichts an
    /// ihre Stelle.
    test('ohne Wert in der neuen Quelle bleibt der getippte stehen', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang(mitAntwort: null));
      final alt = feld('Versicherer');
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': 'von Hand getippt'});

      final aenderung = await wizard.aktualisiereFeld(
        alt,
        feld('Versicherer', quelle: FeldDatenquelle.versichererName),
      );

      expect(aenderung.verdraengterWert, isNull);
      expect(wizard.state.formDataEntwurf, {'Versicherer': 'von Hand getippt'});
    });

    /// Umbenennen, Typ und Pflichthaken sagen nichts darüber, woher der Wert
    /// kommt — sie dürfen ihn deshalb nicht antasten.
    test('eine Änderung ohne neue Quelle lässt den Wert in Ruhe', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      final alt = feld('Versicherer', quelle: FeldDatenquelle.versichererName);
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': 'von Hand getippt'});

      final aenderung = await wizard.aktualisiereFeld(
        alt,
        feld(
          'Versicherung des Gegners',
          required: false,
          quelle: FeldDatenquelle.versichererName,
        ),
      );

      expect(aenderung.verdraengterWert, isNull);
      expect(wizard.state.formDataEntwurf, {
        'Versicherung des Gegners': 'von Hand getippt',
      });
    });

    test('„Alten Wert zurückholen" setzt ihn wieder ein', () async {
      final wizard = umgebung.wizard;
      await wizard.selectVorgang(vorgang());
      final alt = feld('Versicherer');
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': 'von Hand getippt'});
      await wizard.aktualisiereFeld(
        alt,
        feld('Versicherer', quelle: FeldDatenquelle.versichererName),
      );
      final marke = wizard.state.aufbauMarke;

      wizard.stelleFeldWertWiederHer('Versicherer', 'von Hand getippt');

      expect(wizard.state.formDataEntwurf, {'Versicherer': 'von Hand getippt'});
      expect(wizard.state.aufbauMarke, marke + 1);
      // Zurückgeholt wird der Wert, nicht die Vorlagenänderung.
      expect(
        wizard.state.selectedFormTemplate?.fields.single.datenquelle,
        FeldDatenquelle.versichererName,
      );
    });

    /// Ohne Vorgang gibt es keine Vorbelegung, der die Eingabe weichen könnte.
    test('ohne Vorgang bleibt der Wert unangetastet', () async {
      final wizard = umgebung.wizard;
      final alt = feld('Versicherer');
      wizard.selectFormTemplate(vorlage([alt]));
      wizard.setFormDataEntwurf(const {'Versicherer': 'von Hand getippt'});

      final aenderung = await wizard.aktualisiereFeld(
        alt,
        feld('Versicherer', quelle: FeldDatenquelle.versichererName),
      );

      expect(aenderung.verdraengterWert, isNull);
      expect(wizard.state.formDataEntwurf, {'Versicherer': 'von Hand getippt'});
    });
  });
}
