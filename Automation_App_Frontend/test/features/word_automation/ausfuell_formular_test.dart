import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/eingaben_zuruecksetzen_button.dart';
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
///
/// Dazu #133: Der angefangene Stand kommt **ohne Nachfrage** zurück — das
/// Formular zeigt Vorbelegung und Stand gemischt. Damit das keine Einbahnstraße
/// ist, steht darüber der Weg zurück zur Vorbelegung, und der ist kurz
/// zurücknehmbar.
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
  /// vorbelegt — [platzhalter] entscheidet, welche davon oben stehen, [entwurf]
  /// legt einen angefangenen Stand an den Vorgang.
  Future<WizardUmgebung> zeige(
    WidgetTester tester,
    List<String> platzhalter, {
    VorgangEntwurf? entwurf,
  }) async {
    final umgebung = WizardUmgebung(mandanten: [mandant]);
    await umgebung.wizard.selectVorgang(
      Vorgang.ausAnfrage(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 4, 8),
        mandantId: 7,
        mandantName: 'Erika Mustermann',
      ).copyWith(entwurf: () => entwurf),
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
    return umgebung;
  }

  /// Ein Stand, der sich von der Vorbelegung unterscheidet — der einzige, über
  /// den es etwas zu entscheiden gibt.
  VorgangEntwurf abweichenderStand() => VorgangEntwurf(
    gespeichertAm: DateTime(2026, 4, 9, 11, 20),
    feldWerte: const {'Mandant Vorname': 'Erika-Marie'},
  );

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

  /// Der Stand kommt ohne Nachfrage zurück: Vorbelegung und Getipptes stehen
  /// nebeneinander im selben Formular, der Stand gewinnt an seinem Feld.
  testWidgets('zeigt Vorbelegung und angefangenen Stand gemischt', (
    tester,
  ) async {
    await zeige(tester, [
      'Mandant Vorname',
      'Mandant Nachname',
    ], entwurf: abweichenderStand());

    expect(find.text('Erika-Marie'), findsOneWidget, reason: 'der Stand');
    expect(find.text('Mustermann'), findsOneWidget, reason: 'die Vorbelegung');
    expect(find.text('Dokument erstellen'), findsOneWidget);
  });

  /// Wo der Stand den vorbelegten Wert überschreibt, behauptet das Feld keine
  /// Herkunft mehr: Im Feld steht der Wert des Anwalts, nicht der des Bestands.
  testWidgets('nennt für überschriebene Felder keine Herkunft mehr', (
    tester,
  ) async {
    await zeige(tester, [
      'Mandant Vorname',
      'Mandant Nachname',
    ], entwurf: abweichenderStand());

    expect(find.text('Vorbelegt aus dem Mandantenregister'), findsOneWidget);
    expect(
      find.text('1 Feld wurde aus dem Vorgang vorbelegt.'),
      findsOneWidget,
    );
  });

  /// Ein Knopf, der nichts tut, sieht aus wie einer, der nicht funktioniert.
  testWidgets('ohne Abweichung steht kein Zurücksetzen da', (tester) async {
    await zeige(tester, ['Mandant Vorname', 'Mandant Nachname']);

    expect(find.text(EingabenZuruecksetzenButton.beschriftung), findsNothing);
  });

  testWidgets('mit Abweichung steht das Zurücksetzen da', (tester) async {
    await zeige(tester, [
      'Mandant Vorname',
      'Mandant Nachname',
    ], entwurf: abweichenderStand());

    expect(find.text(EingabenZuruecksetzenButton.beschriftung), findsOneWidget);
  });

  /// Zurücksetzen löscht — im Formular und am Vorgang. Deshalb steht die
  /// Rücknahme daneben.
  testWidgets('Zurücksetzen meldet sich mit „Rückgängig"', (tester) async {
    final umgebung = await zeige(tester, [
      'Mandant Vorname',
      'Mandant Nachname',
    ], entwurf: abweichenderStand());

    await tester.tap(find.text(EingabenZuruecksetzenButton.beschriftung));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(umgebung.wizard.state.formDataEntwurf, isEmpty);
    expect(find.text('Erika-Marie'), findsNothing, reason: 'wieder vorbelegt');
    expect(find.text('Erika'), findsOneWidget);
    expect(find.text(EingabenZuruecksetzenButton.meldung), findsOneWidget);
    expect(find.text(EingabenZuruecksetzenButton.rueckgaengig), findsOneWidget);

    await tester.tap(find.text(EingabenZuruecksetzenButton.rueckgaengig));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(umgebung.wizard.state.formDataEntwurf, {
      'Mandant Vorname': 'Erika-Marie',
    });
    expect(find.text('Erika-Marie'), findsOneWidget);
  });

  /// Review-Nachbesserung zu #133, Befund 1: Der `FormWertBeobachter` meldet
  /// eine ausstehende Änderung aus seinem `dispose()` heraus — hier ausgelöst
  /// durch den Vorgangswechsel, der die `aufbauMarke` erhöht und damit das
  /// alte Formular verwirft, bevor die Entprellung (300 ms) abgelaufen ist.
  /// Die Meldung trägt noch die Referenz von A; der Cubit muss sie verwerfen,
  /// statt die getippten Werte auf den inzwischen gewählten Vorgang B zu
  /// schreiben (`wizard_cubit_entwurf_test.dart` prüft denselben Fall ohne
  /// Formular, am Cubit entlang).
  testWidgets(
    'eine späte Meldung des alten Formulars überschreibt den neuen Vorgang '
    'nicht',
    (tester) async {
      final umgebung = await zeige(tester, [
        'Mandant Vorname',
        'Mandant Nachname',
      ]);

      await tester.enterText(find.byType(TextField).first, 'Getippt für A');
      await tester.pump();

      // Der Wechsel geschieht direkt am Cubit, nicht über eine eigene
      // Auswahl-Oberfläche — die liegt außerhalb dieses Widgets.
      await umgebung.wizard.selectVorgang(
        Vorgang.ausAnfrage(
          referenz: '90/26 C03_GG-ZZ 999',
          angefragtAm: DateTime(2026, 4, 9),
        ),
      );
      await tester.pump();

      expect(umgebung.wizard.state.formDataEntwurf, isNull);
    },
  );
}
