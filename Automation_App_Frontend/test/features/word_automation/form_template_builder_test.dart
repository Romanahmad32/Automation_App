import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/word_automation/domain/services/datenquelle_vorschlaege.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/form_template_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Wird die Vorlage bearbeitet, während ihr Formular offen steht, kommt sie mit
/// **gleicher ID** und geänderten Feldern zurück (#37). Der Schlüssel der
/// FormGroup muss das mitbekommen — sonst zeigt das Formular die neuen Felder
/// und arbeitet mit den alten Controls. Der bereits getippte Stand kommt beim
/// Neuaufbau von außen wieder herein, damit der Anwalt nicht von vorn anfängt.
void main() {
  FieldData feld(
    String label, {
    bool required = true,
    InputType inputType = InputType.text,
    DatumsVorbelegung? vorbelegung,
  }) => FieldData(
    order: 0,
    label: label,
    required: required,
    inputType: inputType,
    vorbelegung: vorbelegung,
  );

  FormTemplate vorlage(List<FieldData> fields) =>
      FormTemplate(id: 1, templateName: 'Anspruchsschreiben', fields: fields);

  /// Der Wert, der beim Absenden gelesen wird — nicht irgendein Text auf dem
  /// Schirm.
  Object? imFeld(WidgetTester tester, String name) => tester
      .widget<ReactiveForm>(find.byType(ReactiveForm).first)
      .formGroup
      .control(name)
      .value;

  /// Verlässt das Feld. reactive_forms zeigt die Meldung eines Validators erst
  /// am **berührten** Control — im Betrieb geschieht das, sobald der Fokus
  /// weiterwandert. Der Knopf ist dagegen sofort gesperrt (`formGroup.valid`).
  ///
  /// Der echte Fokusverlust (nicht nur `markAsTouched`) steht mit dabei, damit
  /// derselbe Helfer auch die Normalisierung beim Verlassen des Felds auslöst
  /// (`AuswahlTextField`, `normalisiere`).
  Future<void> verlasse(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    tester
        .widget<ReactiveForm>(find.byType(ReactiveForm).first)
        .formGroup
        .control(name)
        .markAsTouched();
    await tester.pump();
  }

  bool knopfAktiv(WidgetTester tester) =>
      tester
          .widget<CustomRectangularButton>(find.byType(CustomRectangularButton))
          .onPressed !=
      null;

  Future<void> zeige(
    WidgetTester tester,
    FormTemplate template, {
    Map<String, String> vorbelegt = const {},
    Map<String, String> erfasst = const {},
    void Function(Map<String, String>)? onWerte,
    Set<String>? aktivePlatzhalter,
    Map<String, List<FeldVorschlag>> vorschlaege = const {},
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FormTemplateBuilder(
            formTemplate: template,
            initialValues: vorbelegt,
            erfassteWerte: erfasst,
            onWerteGeaendert: onWerte,
            aktivePlatzhalter: aktivePlatzhalter,
            vorschlaege: vorschlaege,
            submitButtonLabel: const Text('Dokument erstellen'),
            onSubmitted: (_) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('ein umbenanntes Feld baut das Formular neu auf', (tester) async {
    await zeige(tester, vorlage([feld('Versicherer'), feld('Kennzeichen')]));
    await tester.enterText(find.byType(TextField).at(0), 'HUK-COBURG');
    await tester.enterText(find.byType(TextField).at(1), 'HG-E 1427');

    await zeige(
      tester,
      vorlage([feld('Versicherung des Gegners'), feld('Kennzeichen')]),
      erfasst: const {'Versicherer': 'HUK-COBURG', 'Kennzeichen': 'HG-E 1427'},
    );

    // Ohne Feldsignatur im Schlüssel griffe `formControlName` hier ins Leere:
    // FormControlNotFoundException, roter Bildschirm.
    expect(tester.takeException(), isNull);
    // Nur das umbenannte Feld verliert seinen Wert — es ist ein anderes Feld.
    expect(imFeld(tester, 'Versicherung des Gegners'), isNull);
    expect(imFeld(tester, 'Kennzeichen'), 'HG-E 1427');
  });

  testWidgets('„nicht erforderlich" wirkt ohne Neustart', (tester) async {
    await zeige(tester, vorlage([feld('Versicherer')]));
    expect(knopfAktiv(tester), isFalse, reason: 'Pflichtfeld ist leer');

    await zeige(tester, vorlage([feld('Versicherer', required: false)]));

    expect(knopfAktiv(tester), isTrue);
  });

  /// Der Gegenprobe-Fall: Ein Rebuild ohne inhaltliche Änderung — etwa weil der
  /// Cubit gerade den Tippstand mitgeschrieben hat — darf das Formular nicht
  /// anfassen. Deshalb steckt [FormTemplateBuilder.erfassteWerte] **nicht** im
  /// Schlüssel.
  testWidgets('ein bloßes Rebuild setzt Eingaben nicht zurück', (tester) async {
    await zeige(tester, vorlage([feld('Versicherer')]));
    await tester.enterText(find.byType(TextField).first, 'HUK-COBURG');

    await zeige(tester, vorlage([feld('Versicherer')]));

    expect(imFeld(tester, 'Versicherer'), 'HUK-COBURG');
  });

  testWidgets('Getipptes hat Vorrang vor der Vorbelegung', (tester) async {
    await zeige(
      tester,
      vorlage([feld('Versicherer')]),
      vorbelegt: const {'Versicherer': 'Allianz'},
      erfasst: const {'Versicherer': 'HUK-COBURG'},
    );

    expect(imFeld(tester, 'Versicherer'), 'HUK-COBURG');
  });

  /// #35 Teil 2: Die Pflicht gilt je gewählter Word-Datei. Das Feld
  /// „Schadenshöhe" steht nur in der Auflistungs-Datei — beim HGN-Schreiben
  /// (dessen Platzhalter es nicht enthalten) darf es den Knopf nicht sperren.
  testWidgets('ein Feld nur aus der Auflistungs-Datei blockiert das '
      'HGN-Schreiben nicht', (tester) async {
    await zeige(
      tester,
      vorlage([feld('Kennzeichen'), feld('Schadenshöhe')]),
      aktivePlatzhalter: {'Kennzeichen'},
    );
    expect(find.textContaining('* Pflichtfeld'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'HG-E 1427');
    await tester.pump();

    expect(knopfAktiv(tester), isTrue);
  });

  testWidgets('…wird beim Auflistungs-Schreiben aber erzwungen', (
    tester,
  ) async {
    await zeige(
      tester,
      vorlage([feld('Kennzeichen'), feld('Schadenshöhe')]),
      aktivePlatzhalter: {'Kennzeichen', 'Schadenshöhe'},
    );

    await tester.enterText(find.byType(TextField).at(0), 'HG-E 1427');
    await tester.pump();
    expect(knopfAktiv(tester), isFalse, reason: 'Schadenshöhe fehlt noch');

    await tester.enterText(find.byType(TextField).at(1), '2810,87');
    await tester.pump();
    expect(knopfAktiv(tester), isTrue);
  });

  testWidgets('„zahlungsfrist" gegen {{Zahlungsfrist}} gilt als Treffer', (
    tester,
  ) async {
    // Die Backend-Ersetzung arbeitet ohne Groß-/Kleinschreibung — die
    // Pflichtprüfung muss denselben Maßstab anlegen.
    await zeige(
      tester,
      vorlage([feld('zahlungsfrist')]),
      aktivePlatzhalter: {'Zahlungsfrist'},
    );

    expect(knopfAktiv(tester), isFalse, reason: 'Pflichtfeld ist leer');
  });

  testWidgets('die leere Platzhaltermenge sperrt nichts', (tester) async {
    // „Solange nichts bekannt ist: nicht sperren" — konnte die Datei nicht
    // gelesen werden, reicht der Aufrufer die leere Menge herein.
    await zeige(
      tester,
      vorlage([feld('Versicherer')]),
      aktivePlatzhalter: const {},
    );

    expect(knopfAktiv(tester), isTrue);
    expect(find.textContaining('* Pflichtfeld'), findsNothing);
  });

  /// #35 Teil 1: Ein app-eigenes Feld (z. B. aus einer alten Vorlage, in der
  /// {{Schadensaufstellung}} als Pflichtfeld übernommen wurde) füllt die App
  /// selbst — es darf den Knopf nie sperren und sich nicht als Pflichtfeld
  /// ausgeben.
  testWidgets('ein app-eigenes Pflichtfeld sperrt den Knopf nicht', (
    tester,
  ) async {
    await zeige(
      tester,
      vorlage([feld('Schadensaufstellung'), feld('Kennzeichen')]),
    );
    expect(knopfAktiv(tester), isFalse, reason: 'Kennzeichen fehlt noch');
    expect(find.textContaining('* Pflichtfeld'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'HG-E 1427');
    await tester.pump();

    expect(knopfAktiv(tester), isTrue);
  });

  /// #35 Teil 3: Statt eines kommentarlos toten Knopfs sagt eine Zeile,
  /// welche Pflichtfelder fehlen, und springt beim Anklicken ins Feld.
  testWidgets('nennt die fehlenden Pflichtfelder und springt beim Klick', (
    tester,
  ) async {
    await zeige(
      tester,
      vorlage([feld('Unfalldatum'), feld('Versicherer'), feld('Ort')]),
    );
    await tester.enterText(find.byType(TextField).at(2), 'Bad Homburg');
    await tester.pump();

    expect(find.text('2 Pflichtfelder fehlen:'), findsOneWidget);
    expect(find.text('Versicherer'), findsWidgets);

    await tester.tap(find.text('Unfalldatum').last);
    await tester.pump();
    final control =
        tester
                .widget<ReactiveForm>(find.byType(ReactiveForm).first)
                .formGroup
                .control('Unfalldatum')
            as FormControl<String>;
    expect(control.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField).at(0), '01.01.2026');
    await tester.enterText(find.byType(TextField).at(1), 'HUK-COBURG');
    await tester.pump();
    expect(find.textContaining('Pflichtfeld fehl'), findsNothing);
    expect(knopfAktiv(tester), isTrue);
  });

  /// Das Datum, mit dem ein Datumsfeld vorbelegt sein muss. Gerechnet wird
  /// über dieselbe Entität wie im Code — die Kalenderregel steht in ihren
  /// eigenen Tests, hier geht es nur darum, dass sie ankommt. Läuft der Test
  /// über Mitternacht, ist auch der Folgetag richtig.
  Matcher datumFuer(DatumsVorbelegung vorbelegung) {
    final heute = DateTime.now();
    return isIn([
      deutschesDatum(vorbelegung.anwendenAuf(heute)),
      deutschesDatum(
        vorbelegung.anwendenAuf(heute.add(const Duration(days: 1))),
      ),
    ]);
  }

  FieldData datumsfeld(String label, {DatumsVorbelegung? vorbelegung}) =>
      feld(label, inputType: InputType.date, vorbelegung: vorbelegung);

  /// §5.3: Die Vorbelegung eines Datumsfelds ist je Feld einstellbar. Der
  /// eingestellte Wert gewinnt — der Feldname sagt dann nichts mehr dazu.
  testWidgets('eine eingestellte Vorbelegung schlägt im Feld auf', (
    tester,
  ) async {
    await zeige(
      tester,
      vorlage([
        datumsfeld(
          'Wiedervorlage',
          vorbelegung: const DatumsVorbelegung(wochen: 2),
        ),
      ]),
    );

    expect(
      imFeld(tester, 'Wiedervorlage'),
      datumFuer(const DatumsVorbelegung(wochen: 2)),
    );
  });

  /// Bestandsvorlagen tragen keine Vorbelegung — für sie gilt die Namensregel
  /// weiter, damit niemand sie nachtragen muss.
  testWidgets('ein Feld „Frist" ohne Einstellung bekommt 4 Wochen', (
    tester,
  ) async {
    await zeige(tester, vorlage([datumsfeld('Frist')]));

    expect(
      imFeld(tester, 'Frist'),
      datumFuer(const DatumsVorbelegung(wochen: 4)),
    );
  });

  /// Die Unterscheidung, an der alles hängt: **lauter Nullen ist eine
  /// Einstellung**, kein fehlender Wert. Fiele sie auf die Namensregel
  /// zurück, liesse sich die Ableitung an einem Feld namens „zahlungsfrist"
  /// nie abschalten.
  testWidgets('eingestellte Nullen fallen nicht auf die Namensregel zurück', (
    tester,
  ) async {
    await zeige(
      tester,
      vorlage([
        datumsfeld('zahlungsfrist', vorbelegung: const DatumsVorbelegung()),
      ]),
    );

    expect(
      imFeld(tester, 'zahlungsfrist'),
      datumFuer(const DatumsVorbelegung()),
    );
    expect(
      imFeld(tester, 'zahlungsfrist'),
      isNot(datumFuer(const DatumsVorbelegung(wochen: 5))),
    );
  });

  testWidgets('meldet den Tippstand entprellt', (tester) async {
    Map<String, String>? gemeldet;
    await zeige(
      tester,
      vorlage([feld('Versicherer')]),
      onWerte: (werte) => gemeldet = werte,
    );

    await tester.enterText(find.byType(TextField).first, 'HUK-COBURG');
    await tester.pump(const Duration(milliseconds: 500));
    expect(gemeldet, isNull, reason: 'nicht bei jedem Tastendruck');

    await tester.pump(const Duration(seconds: 2));
    expect(gemeldet, const {'Versicherer': 'HUK-COBURG'});
  });

  /// #17: Das Kennzeichenfeld prüft sein Format. Beanstandet wird am
  /// **Wortlaut der Konvention** und nicht mit „ungültig": `HG-E 1427` erklärt
  /// in vier Zeichen, was drei Sätze bräuchten.
  group('Kennzeichenfeld', () {
    FieldData kennzeichenfeld({bool required = false}) =>
        feld('Fahrzeug', required: required, inputType: InputType.kennzeichen);

    testWidgets('ein unlesbarer Wert wird beanstandet und sperrt den Knopf', (
      tester,
    ) async {
      await zeige(tester, vorlage([kennzeichenfeld()]));

      await tester.enterText(find.byType(TextField).first, 'kein kennzeichen');
      await tester.pump();
      expect(knopfAktiv(tester), isFalse);

      await verlasse(tester, 'Fahrzeug');
      expect(find.text('Kennzeichen wie HG-E 1427 eingeben'), findsOneWidget);
    });

    testWidgets('ein lesbarer Wert geht durch', (tester) async {
      await zeige(tester, vorlage([kennzeichenfeld()]));

      await tester.enterText(find.byType(TextField).first, 'HG-E 1427');
      await verlasse(tester, 'Fahrzeug');

      expect(find.text('Kennzeichen wie HG-E 1427 eingeben'), findsNothing);
      expect(knopfAktiv(tester), isTrue);
    });

    /// Leer heisst „noch nicht beziffert" und nicht „falsch" — ob das Feld
    /// gefüllt sein muss, entscheidet allein die Pflichtmarkierung.
    testWidgets('leer ist ohne Pflicht in Ordnung', (tester) async {
      await zeige(tester, vorlage([kennzeichenfeld()]));
      await verlasse(tester, 'Fahrzeug');

      expect(find.text('Kennzeichen wie HG-E 1427 eingeben'), findsNothing);
      expect(knopfAktiv(tester), isTrue);
    });

    /// Nicht nur die freie Eingabe im Auswahldialog, auch der direkt
    /// getippte Wert soll die Konvention tragen — sonst hinge es vom Zufall
    /// ab, ob der Anwalt den Dialog benutzt oder gleich tippt.
    testWidgets('ein direkt getippter Wert wird beim Verlassen normalisiert', (
      tester,
    ) async {
      await zeige(tester, vorlage([kennzeichenfeld()]));

      await tester.enterText(find.byType(TextField).first, 'hg-e1427');
      await verlasse(tester, 'Fahrzeug');

      expect(imFeld(tester, 'Fahrzeug'), 'HG-E 1427');
    });

    testWidgets('leer sperrt, wenn das Feld Pflicht ist', (tester) async {
      await zeige(tester, vorlage([kennzeichenfeld(required: true)]));

      // Wie bei jedem anderen Feldtyp: Der Hinweis unter dem Formular nennt
      // das leere Pflichtfeld, statt den Knopf kommentarlos tot dastehen zu
      // lassen (#35 Teil 3).
      expect(find.text('1 Pflichtfeld fehlt:'), findsOneWidget);
      expect(find.text('Fahrzeug'), findsWidgets);
      expect(knopfAktiv(tester), isFalse);
    });

    testWidgets('bekannte Werte stehen als Auswahl daneben', (tester) async {
      await zeige(
        tester,
        vorlage([kennzeichenfeld()]),
        vorschlaege: const {
          'Fahrzeug': [
            FeldVorschlag('HG-E 1427', PrefillQuelle.vorgang),
            FeldVorschlag('F-AB 12', PrefillQuelle.mandant),
          ],
        },
      );

      expect(find.byIcon(Icons.list_alt), findsOneWidget);
    });
  });

  /// Die Auswahlhilfe hängt an der **Datenquelle**, nicht am Feldtyp: Sind zu
  /// einem gewöhnlichen Textfeld mehrere Werte bekannt, bekommt es die Liste
  /// genauso. Sonst hätte dieselbe Angabe je Feldtyp eine andere Bedienung.
  group('Auswahlhilfe am Textfeld', () {
    testWidgets('ohne Vorschläge bleibt es ein blankes Textfeld', (
      tester,
    ) async {
      await zeige(tester, vorlage([feld('Fahrzeug', required: false)]));

      expect(find.byIcon(Icons.list_alt), findsNothing);
    });

    testWidgets('mit Vorschlägen trägt es das Auswahlsymbol', (tester) async {
      await zeige(
        tester,
        vorlage([feld('Fahrzeug', required: false)]),
        vorschlaege: const {
          'Fahrzeug': [FeldVorschlag('F-AB 12', PrefillQuelle.mandant)],
        },
      );

      expect(find.byIcon(Icons.list_alt), findsOneWidget);

      await tester.tap(find.byIcon(Icons.list_alt));
      await tester.pumpAndSettle();

      // Die Herkunft steht im Dialog im Wortlaut der Herkunftszeile am Feld.
      expect(find.text('aus dem Mandantenregister'), findsOneWidget);

      await tester.tap(find.text('F-AB 12'));
      await tester.pumpAndSettle();

      expect(imFeld(tester, 'Fahrzeug'), 'F-AB 12');
    });
  });
}
