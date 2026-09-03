import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Antwortet sofort mit einer festen Platzhaltermenge — hier geht es nicht um
/// das Laden (das prüft `aktive_platzhalter_cubit_test.dart`), sondern darum,
/// was das Formular daraus macht.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  final List<String> platzhalter;

  FestePlatzhalter(this.platzhalter);

  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(platzhalter);
}

/// #82: „N Felder wurden aus dem Vorgang vorbelegt" und die Sichtbarkeit dürfen
/// nicht auseinanderlaufen. Die Zahl nennt nur, was **dieses** Schreiben auch
/// einsetzt — sonst schickt sie den Anwalt auf die Suche nach Feldern, die
/// eingeklappt unter der Zeile „… die dieses Schreiben nicht verwendet" liegen.
///
/// Vorbelegt werden weiterhin alle Felder: Die eingeklappten behalten ihren
/// Wert für die andere Vorlagenfassung.
void main() {
  const pfad = r'C:\Vorlagen\hgn.docx';

  final mandant = Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    erstelltAm: DateTime(2026, 1, 1),
  );

  FieldData feld(String label) => FieldData(
    order: 0,
    label: label,
    required: false,
    inputType: InputType.text,
  );

  final vorlage = FormTemplate(
    id: 1,
    templateName: 'Anspruchsschreiben',
    fields: [feld('Mandant Vorname'), feld('Mandant Nachname')],
  );

  /// Baut das Formular zu einem Vorgang, dessen Mandant Vor- und Nachnamen
  /// vorbelegt — [platzhalter] entscheidet, welche davon oben stehen.
  Future<void> zeige(WidgetTester tester, List<String> platzhalter) async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);
    await umgebung.wizard.selectVorgang(
      Vorgang.ausAnfrage(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 4, 8),
        mandantId: 7,
        mandantName: 'Erika Mustermann',
      ),
    );
    final platzhalterCubit = AktivePlatzhalterCubit(
      FestePlatzhalter(platzhalter),
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
  }

  testWidgets('der Hinweis zählt nur die Vorbelegungen, die dieses Schreiben '
      'einsetzt', (tester) async {
    await zeige(tester, ['Mandant Vorname']);

    expect(
      find.text('1 Feld wurde aus dem Vorgang vorbelegt.'),
      findsOneWidget,
    );
    // Gegenprobe: Vorbelegt sind trotzdem beide — „Nachname" liegt nur
    // eingeklappt darunter.
    expect(
      find.text('1 Feld, das dieses Schreiben nicht verwendet'),
      findsOneWidget,
    );
  });

  testWidgets('…und alle, solange das Schreiben alle einsetzt', (tester) async {
    await zeige(tester, ['Mandant Vorname', 'Mandant Nachname']);

    expect(
      find.text('2 Felder wurden aus dem Vorgang vorbelegt.'),
      findsOneWidget,
    );
  });

  testWidgets('ohne lesbare Platzhalter bleibt die Zahl vollständig', (
    tester,
  ) async {
    // Leere Menge = nichts bekannt. Dann wird nichts eingeklappt, also darf
    // die Zahl auch nichts unterschlagen.
    await zeige(tester, const []);

    expect(
      find.text('2 Felder wurden aus dem Vorgang vorbelegt.'),
      findsOneWidget,
    );
  });
}
