import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/eingaben_zuruecksetzen_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ausfuell_formular_test.dart' show FestePlatzhalter;
import 'wizard_doubles.dart';

/// #133 Mangel 2: `FormTemplateBuilder` belegt ein leeres Datumsfeld sichtbar
/// mit dem heutigen Datum vor — automatisch, nicht getippt. Kannte der
/// Abweichungsvergleich diesen Vorschlag nicht, zählte er dennoch als Eingabe
/// des Anwalts: Das Feld landete im Entwurf, und der Zurücksetzen-Link
/// erschien, ohne dass er das Feld je angerührt hatte. `AusgangsBelegung` ist
/// seither die eine Quelle für beide Seiten — diese Datei prüft das Ergebnis
/// am echten Formular.
void main() {
  const pfad = r'C:\Vorlagen\mahnung.docx';
  const feldname = 'Unfalldatum';

  final vorlage = FormTemplate(
    id: 3,
    templateName: 'Mahnung',
    fields: const [
      FieldData(
        order: 0,
        label: feldname,
        required: false,
        inputType: InputType.date,
      ),
    ],
  );

  /// Der Vorschlag, mit dem das leere Feld startet: heute, ohne Vorbelegung
  /// (der Feldname trägt weder „frist" noch „zahlungsfrist").
  final heutigerVorschlag = deutschesDatum(DateTime.now());

  Future<WizardUmgebung> zeige(WidgetTester tester) async {
    final umgebung = WizardUmgebung();
    await umgebung.wizard.selectVorgang(
      Vorgang.ausAnfrage(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 4, 8),
      ),
    );
    final platzhalterCubit = AktivePlatzhalterCubit(
      FestePlatzhalter([feldname]),
    );
    await platzhalterCubit.lade(pfad);
    addTearDown(() async {
      await platzhalterCubit.close();
      await umgebung.schliesse();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: umgebung.wizard),
              BlocProvider.value(value: platzhalterCubit),
            ],
            child: SingleChildScrollView(
              child: AusfuellFormular(template: vorlage, wordDateiPfad: pfad),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return umgebung;
  }

  testWidgets('das Feld startet mit dem heutigen Datum vorbelegt', (
    tester,
  ) async {
    await zeige(tester);

    expect(find.text(heutigerVorschlag), findsOneWidget);
  });

  /// Der Beobachter meldet den vollständigen Formularstand — auch wenn das
  /// Datumsfeld am Ende wieder bei seinem eigenen Vorschlag steht (z. B. der
  /// Anwalt tippt hinein und macht es rückgängig, bevor er das Feld
  /// verlässt). Genau dieser gemeldete, aber inhaltlich unveränderte Wert
  /// hielt vor #133 für eine Eingabe.
  testWidgets('der unveränderte Datumsvorschlag zählt nicht als Abweichung', (
    tester,
  ) async {
    final umgebung = await zeige(tester);

    await tester.enterText(find.byType(TextField).first, '01.01.2020');
    await tester.enterText(find.byType(TextField).first, heutigerVorschlag);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(umgebung.wizard.state.formDataEntwurf, isEmpty);
    expect(find.text(EingabenZuruecksetzenButton.beschriftung), findsNothing);
    expect(umgebung.ablage.entwuerfe, isEmpty);
  });

  testWidgets('ein vom Anwalt geändertes Datum ist eine Abweichung', (
    tester,
  ) async {
    final umgebung = await zeige(tester);

    await tester.enterText(find.byType(TextField).first, '01.01.2020');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(umgebung.wizard.state.formDataEntwurf, {feldname: '01.01.2020'});
    expect(find.text(EingabenZuruecksetzenButton.beschriftung), findsOneWidget);
  });
}
