import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
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
  FieldData feld(String label, {bool required = true}) => FieldData(
    order: 0,
    label: label,
    required: required,
    inputType: InputType.text,
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
}
