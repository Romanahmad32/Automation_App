import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schreiben_nummer_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Antwortet sofort mit einer festen Platzhaltermenge — geladen wird hier
/// nichts, geprüft wird, was das Formular daraus macht.
class _FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  final List<String> platzhalter;

  _FestePlatzhalter(this.platzhalter);

  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(platzhalter);
}

/// #133 Teil A am Ausfüllschritt: Die Frage „Korrektur oder neues Schreiben"
/// hängt am **gespeicherten** Schreiben, nicht am erzeugten. Und sie ist nicht
/// vorbelegt — solange niemand gewählt hat, sagt die App vor dem Erstellen, was
/// fehlt, statt den Knopf wortlos zu sperren (§4.9, vgl. #130).
void main() {
  const pfad = r'C:\Vorlagen\hgn.docx';
  const arbeitskopie = r'C:\Arbeit\84-26 C03\Anspruchsschreiben 1 HGn.docx';
  const inDerAkte =
      r'C:\Akten\Mustermann\VU\Anspruchsschreiben an Allianz 1 HGn.docx';

  final vorlage = FormTemplate(
    id: 1,
    templateName: 'HGn',
    fields: [
      FieldData(
        order: 0,
        label: 'Mandant Nachname',
        required: false,
        inputType: InputType.text,
      ),
    ],
  );

  Future<WizardUmgebung> zeige(WidgetTester tester, Vorgang vorgang) async {
    final umgebung = WizardUmgebung();
    umgebung.ablage.vorgaenge = [vorgang];
    await umgebung.wizard.selectVorgang(vorgang);

    final platzhalter = AktivePlatzhalterCubit(
      _FestePlatzhalter(const ['Mandant Nachname']),
    );
    await platzhalter.lade(pfad);
    addTearDown(() async {
      await platzhalter.close();
      await umgebung.schliesse();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: umgebung.wizard),
              BlocProvider.value(value: platzhalter),
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

  bool knopfFrei(WidgetTester tester) =>
      tester
          .widget<CustomRectangularButton>(find.byType(CustomRectangularButton))
          .onPressed !=
      null;

  /// Erzeugt, aber nie abgelegt: Der Vorgang trägt eine Arbeitskopie und keine
  /// Nummer. Vor #133 stand hier schon die Frage — obwohl es nichts gibt, das
  /// eine Korrektur ersetzen könnte.
  testWidgets('erzeugt, aber nicht gespeichert: keine Frage', (tester) async {
    await zeige(
      tester,
      Vorgang(
        referenz: '84/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 12),
        status: VorgangStatus.erstellt,
        dokumentPfad: arbeitskopie,
      ),
    );

    expect(find.byType(SchreibenNummerHinweis), findsNothing);
    expect(knopfFrei(tester), isTrue);
  });

  testWidgets('nach dem Speichern: Frage mit Nummer und Dateinamen', (
    tester,
  ) async {
    await zeige(
      tester,
      Vorgang(
        referenz: '84/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 12),
        status: VorgangStatus.abgelegt,
        schreibenNummer: 1,
        dokumentPfad: inDerAkte,
        aktenOrdner: 'Mustermann',
      ),
    );

    // Wortlaut an die kompaktere Gestalt angepasst (Variante B, 14.09.2026,
    // auf ausdrücklichen Auftrag): Die Zeile trägt jetzt zwei generische
    // Chips statt nummerierter Segmente, der Dateiname steht erst nach der
    // Wahl „Korrektur" in der Unterzeile — vor der Wahl nennt sie nur die
    // Nummer des gespeicherten Schreibens.
    expect(find.byType(SchreibenNummerHinweis), findsOneWidget);
    expect(
      find.text('Zu diesem Vorgang ist Nr. 1 gespeichert.'),
      findsOneWidget,
    );
    expect(
      find.text(SchreibenNummerHinweis.korrekturChipLabel),
      findsOneWidget,
    );
    expect(find.text(SchreibenNummerHinweis.neuChipLabel), findsOneWidget);
  });

  testWidgets('ohne Wahl sagt die App, was fehlt — und erzeugt nicht', (
    tester,
  ) async {
    await zeige(
      tester,
      Vorgang(
        referenz: '84/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 12),
        status: VorgangStatus.abgelegt,
        schreibenNummer: 1,
        dokumentPfad: inDerAkte,
      ),
    );

    expect(find.text(SchreibenNummerHinweis.wahlFehltHinweis), findsOneWidget);
    expect(knopfFrei(tester), isFalse);
  });

  testWidgets('nach der Wahl ist der Weg frei', (tester) async {
    final umgebung = await zeige(
      tester,
      Vorgang(
        referenz: '84/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 12),
        status: VorgangStatus.abgelegt,
        schreibenNummer: 1,
        dokumentPfad: inDerAkte,
      ),
    );

    await tester.tap(find.text(SchreibenNummerHinweis.neuChipLabel));
    await tester.pump();

    expect(umgebung.wizard.state.neuesSchreiben, isTrue);
    expect(find.text(SchreibenNummerHinweis.wahlFehltHinweis), findsNothing);
    expect(knopfFrei(tester), isTrue);
  });
}
