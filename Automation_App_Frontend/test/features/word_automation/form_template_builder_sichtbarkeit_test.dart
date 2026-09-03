import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/form_template_builder.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/nicht_verwendete_felder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// #82: Eine Vorlage hat zwei Word-Dateien, aber eine Feldliste. Was nur in der
/// **anderen** Datei als `{{Platzhalter}}` steht, geht beim Erzeugen ins Leere —
/// wer es ausfüllt, tippt in den Papierkorb. Es steht deshalb nicht mehr oben,
/// sondern eingeklappt darunter.
///
/// Eingeklappt, nicht entfernt: die Controls bleiben in der `FormGroup`, sonst
/// verlöre der Wechsel zwischen den Fassungen den Tippstand der jeweils anderen
/// Seite.
void main() {
  FieldData feld(String label) => FieldData(
    order: 0,
    label: label,
    required: false,
    inputType: InputType.text,
  );

  FormTemplate vorlage(List<FieldData> fields) =>
      FormTemplate(id: 1, templateName: 'Anspruchsschreiben', fields: fields);

  Future<void> zeige(
    WidgetTester tester, {
    required Set<String>? aktivePlatzhalter,
    Map<String, String> erfasst = const {},
    void Function(Map<String, String>)? onWerte,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FormTemplateBuilder(
            formTemplate: vorlage([
              feld('Gegnerkennzeichen'),
              feld('Vorname'),
              feld('Unfalldatum'),
            ]),
            erfassteWerte: erfasst,
            onWerteGeaendert: onWerte,
            aktivePlatzhalter: aktivePlatzhalter,
            onSubmitted: (_) {},
          ),
        ),
      ),
    ),
  );

  /// Ob das Feld sichtbar im Formular steht — der eingeklappte Teil baut seine
  /// Zeilen erst beim Aufklappen.
  bool stehtOben(String label) =>
      find.widgetWithText(TextField, label).evaluate().isNotEmpty;

  testWidgets('ein Feld nur aus der Auflistungs-Datei liegt beim '
      'HGN-Schreiben im eingeklappten Teil', (tester) async {
    await zeige(tester, aktivePlatzhalter: {'Gegnerkennzeichen'});

    expect(stehtOben('Gegnerkennzeichen'), isTrue);
    expect(stehtOben('Vorname'), isFalse);
    expect(stehtOben('Unfalldatum'), isFalse);
    expect(
      find.text('2 Felder, die dieses Schreiben nicht verwendet'),
      findsOneWidget,
    );

    await tester.tap(find.byType(NichtVerwendeteFelder));
    await tester.pumpAndSettle();

    expect(stehtOben('Vorname'), isTrue, reason: 'aufgeklappt wieder da');
  });

  testWidgets('…und beim Auflistungs-Schreiben oben', (tester) async {
    await zeige(
      tester,
      aktivePlatzhalter: {'Gegnerkennzeichen', 'Vorname', 'Unfalldatum'},
    );

    expect(stehtOben('Vorname'), isTrue);
    expect(find.byType(NichtVerwendeteFelder), findsNothing);
  });

  testWidgets('ohne bekannte Platzhalter wird nichts eingeklappt', (
    tester,
  ) async {
    // Leere Menge = Datei nicht lesbar. Anders als bei der Pflicht („nichts
    // sperren") gilt hier: im Zweifel zeigen — sonst verschluckte ein
    // Lesefehler das ganze Formular.
    await zeige(tester, aktivePlatzhalter: const {});

    expect(stehtOben('Vorname'), isTrue);
    expect(stehtOben('Unfalldatum'), isTrue);
    expect(find.byType(NichtVerwendeteFelder), findsNothing);
  });

  testWidgets('der Tippstand eines eingeklappten Feldes überlebt den '
      'Variantenwechsel', (tester) async {
    Map<String, String>? gemeldet;

    // Auflistungs-Fassung: alles sichtbar, „Vorname" wird ausgefüllt.
    await zeige(
      tester,
      aktivePlatzhalter: {'Gegnerkennzeichen', 'Vorname', 'Unfalldatum'},
      onWerte: (werte) => gemeldet = werte,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Vorname'),
      'Nikolaus',
    );
    await tester.pump(const Duration(seconds: 3));
    expect(gemeldet?['Vorname'], 'Nikolaus');

    // Umschalten auf HGN: „Vorname" klappt ein, der Wert kommt über
    // `erfassteWerte` zurück in die neu gebaute Gruppe.
    await zeige(
      tester,
      aktivePlatzhalter: {'Gegnerkennzeichen'},
      erfasst: gemeldet!,
      onWerte: (werte) => gemeldet = werte,
    );
    expect(stehtOben('Vorname'), isFalse);

    // Und der Beobachter meldet ihn weiter mit — fiele das Control aus der
    // Gruppe, wäre der Wert beim nächsten Tastendruck aus dem Entwurf.
    await tester.enterText(
      find.widgetWithText(TextField, 'Gegnerkennzeichen'),
      'HG-E 1427',
    );
    await tester.pump(const Duration(seconds: 3));
    expect(gemeldet, {
      'Gegnerkennzeichen': 'HG-E 1427',
      'Vorname': 'Nikolaus',
      'Unfalldatum': '',
    });
  });

  /// Der eingeklappte Teil darf den Knopf nicht sperren: Sein Fehler wäre
  /// unsichtbar (das Control ist zugeklappt nicht gebaut) und
  /// `PflichtfelderHinweis` meldet nur fehlende Pflichtfelder — der Knopf
  /// stünde ohne erkennbaren Grund tot da.
  testWidgets('ein ungültiges Datum im eingeklappten Teil sperrt den Knopf '
      'nicht', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormTemplateBuilder(
              formTemplate: vorlage([
                feld('Gegnerkennzeichen'),
                FieldData(
                  order: 1,
                  label: 'Unfalldatum',
                  required: false,
                  inputType: InputType.date,
                ),
              ]),
              // In der Auflistungs-Fassung angefangen zu tippen, dann auf HGN
              // umgeschaltet: Das halbe Datum kommt hier wieder herein.
              erfassteWerte: const {'Unfalldatum': '1.1.'},
              aktivePlatzhalter: const {'Gegnerkennzeichen'},
              submitButtonLabel: const Text('Dokument erstellen'),
              onSubmitted: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(stehtOben('Unfalldatum'), isFalse);
    expect(
      tester
              .widget<CustomRectangularButton>(
                find.byType(CustomRectangularButton),
              )
              .onPressed !=
          null,
      isTrue,
      reason: 'der unsichtbare Formatfehler darf nicht sperren',
    );
  });

  /// Datumsfelder werden mit dem heutigen Datum vorbelegt — als *sichtbarer*
  /// Vorschlag. Zugeklappt liefe dieser erfundene Wert unkorrigierbar über
  /// `ursachendatumAusFormular` in den Dateinamen des Schreibens.
  testWidgets('ein eingeklapptes Datumsfeld bekommt keine Vorbelegung', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormTemplateBuilder(
              formTemplate: vorlage([
                feld('Gegnerkennzeichen'),
                FieldData(
                  order: 1,
                  label: 'Unfalldatum',
                  required: false,
                  inputType: InputType.date,
                ),
              ]),
              aktivePlatzhalter: const {'Gegnerkennzeichen'},
              onSubmitted: (_) {},
            ),
          ),
        ),
      ),
    );

    final gruppe = tester
        .widget<ReactiveForm>(find.byType(ReactiveForm).first)
        .formGroup;
    expect(gruppe.control('Unfalldatum').value, isNull);
  });

  testWidgets('der eingeklappte Wert steht beim Absenden im Formular', (
    tester,
  ) async {
    // Gegenprobe zur Sichtbarkeit: Was eingeklappt ist, bleibt Teil der
    // FormGroup — das Absenden liest es mit.
    await zeige(
      tester,
      aktivePlatzhalter: {'Gegnerkennzeichen'},
      erfasst: const {'Vorname': 'Nikolaus'},
    );

    final gruppe = tester
        .widget<ReactiveForm>(find.byType(ReactiveForm).first)
        .formGroup;
    expect(gruppe.control('Vorname').value, 'Nikolaus');
  });
}
