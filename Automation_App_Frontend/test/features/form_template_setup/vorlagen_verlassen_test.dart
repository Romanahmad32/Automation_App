import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Rückfrage beim Verlassen des Vorlageneditors (#104, §1.3).
///
/// Geprüft wird am **ganzen Weg hinaus**: echter Navigator-Push, echte Seite,
/// echter Abbrechen-Knopf — denn genau dort lag der Fehler. Die Seite hatte
/// keinerlei Änderungserkennung, und `formGroup.dirty` hätte sie auch nicht
/// gehabt: Er kennt nur Vorlagen- und Feldnamen.
///
/// Von Hand geschriebene Fakes wie in den Nachbardateien — dieser Testordner
/// kennt keine Mock-Bibliothek.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(const ['Kennzeichen']);
}

class StillesErstellen implements UseCase<void, CreateFormTemplateRequest> {
  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async =>
      Right(null);
}

class StillesAktualisieren
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(
    UpdateFormTemplateParams params,
  ) async => Right(params.formTemplate);
}

/// Hält das Speichern an, bis der Test [freigabe] erfüllt — nur so lässt sich
/// der Zustand „wird gerade geschrieben" überhaupt beobachten.
class AngehaltenesAktualisieren
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  final Completer<FormTemplate> freigabe = Completer<FormTemplate>();

  @override
  Future<Either<Failure, FormTemplate>> call(
    UpdateFormTemplateParams params,
  ) async => Right(await freigabe.future);
}

void main() {
  const vorlage = FormTemplate(
    id: 7,
    templateName: 'Anspruchsschreiben',
    fields: [
      FieldData(
        order: 0,
        label: 'Kennzeichen',
        required: true,
        inputType: InputType.text,
      ),
    ],
    wordFilePathOhneAuflistung: 'HGN.docx',
  );

  /// Was die Seite beim Verlassen zurückgibt — und ob sie überhaupt schon weg
  /// ist. `null` als Ergebnis wäre von „noch offen" sonst nicht zu trennen.
  bool gepoppt = false;
  bool? ergebnis;

  final verwerfenFrage = find.text('Änderungen verwerfen?');
  final abbrechen = find.text('Abbrechen');
  final namensfeld = find.byWidgetPredicate(
    (widget) =>
        widget is GeneralTextField && widget.formControlName == 'templateName',
  );

  Future<void> tippeAuf(WidgetTester tester, Finder ziel) async {
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  /// Öffnet den Editor über einen echten Push, damit `PopScope` eine Route
  /// unter sich hat und das Ergebnis des Pops messbar wird.
  Future<void> oeffneEditor(
    WidgetTester tester, {
    UseCase<FormTemplate, UpdateFormTemplateParams>? aktualisieren,
  }) async {
    // Die Feldzeile ist für die 800-px-Standardfläche des Testers zu schmal.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    gepoppt = false;
    ergebnis = null;

    final platzhalter = TemplatePlaceholdersBloc(FestePlatzhalter());
    addTearDown(platzhalter.close);
    final daten = FormTemplateDataBloc(
      StillesErstellen(),
      aktualisieren ?? StillesAktualisieren(),
    );
    addTearDown(daten.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final wert = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: daten),
                          BlocProvider.value(value: platzhalter),
                        ],
                        child: const FormTemplateDetailsPage(
                          formTemplate: vorlage,
                        ),
                      ),
                    ),
                  );
                  gepoppt = true;
                  ergebnis = wert;
                },
                child: const Text('Editor öffnen'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Vorlage bearbeiten'), findsOneWidget);
  }

  testWidgets('ohne Änderungen fragt Abbrechen nicht und meldet keine '
      'Änderung', (tester) async {
    await oeffneEditor(tester);

    await tippeAuf(tester, abbrechen);

    expect(verwerfenFrage, findsNothing);
    expect(gepoppt, isTrue);
    // Früher lieferte Abbrechen `true` wie ein Speichern — die Übersicht lud
    // danach grundlos neu (`form_template_row.dart`).
    expect(ergebnis, isFalse);
  });

  testWidgets('eine Umbenennung führt zur Rückfrage', (tester) async {
    await oeffneEditor(tester);

    await tester.enterText(namensfeld, 'Anspruchsschreiben (neu)');
    await tester.pumpAndSettle();

    await tippeAuf(tester, abbrechen);
    expect(verwerfenFrage, findsOneWidget);

    // „Weiter bearbeiten": Der Editor bleibt stehen, samt dem, was drinsteht.
    await tippeAuf(tester, find.text('Weiter bearbeiten'));
    expect(verwerfenFrage, findsNothing);
    expect(gepoppt, isFalse);
    expect(find.text('Vorlage bearbeiten'), findsOneWidget);

    // „Verwerfen": Jetzt geht die Seite — und meldet, dass nichts gespeichert
    // wurde.
    await tippeAuf(tester, abbrechen);
    await tippeAuf(tester, find.text('Verwerfen'));

    expect(gepoppt, isTrue);
    expect(ergebnis, isFalse);
  });

  testWidgets('auch der Pflichthaken zählt als Änderung', (tester) async {
    // Der Fall, den `formGroup.dirty` nicht sieht: Pflicht, Typ, Datenquelle,
    // Vorbelegung und Reihenfolge liegen im Zustand der Seite, nicht im
    // Formular. Ohne den Schnappschuss ginge das hier wortlos verloren.
    await oeffneEditor(tester);

    await tippeAuf(tester, find.byType(Checkbox).first);
    await tippeAuf(tester, abbrechen);

    expect(verwerfenFrage, findsOneWidget);
    expect(gepoppt, isFalse);
  });

  testWidgets('das Entfernen der Word-Datei zählt als Änderung', (
    tester,
  ) async {
    // Der einzige Mutationspfad, der weder durch die FormGroup noch durch die
    // Feldliste läuft: Die beiden Word-Pfade liegen für sich im Zustand der
    // Seite.
    await oeffneEditor(tester);

    await tippeAuf(tester, find.byTooltip('Verknüpfung entfernen'));
    await tippeAuf(tester, abbrechen);

    expect(verwerfenFrage, findsOneWidget);
    expect(gepoppt, isFalse);
  });

  testWidgets('während des Speicherns bleibt jeder Weg hinaus zu', (
    tester,
  ) async {
    // Sonst stünde der Verwerfen-Dialog offen, wenn der Erfolg eintrifft: Der
    // `Navigator.pop(true)` der Seite träfe dann die oberste Route — den
    // Dialog —, `bestaetigen` löste als „verwerfen" auf und die Wache schlösse
    // die Seite mit `false`. Die Übersicht bliebe nach erfolgreichem Speichern
    // auf dem alten Stand stehen, ohne Fehler und ohne Meldung.
    final angehalten = AngehaltenesAktualisieren();
    await oeffneEditor(tester, aktualisieren: angehalten);

    await tester.enterText(namensfeld, 'Anspruchsschreiben (neu)');
    await tester.pumpAndSettle();
    await tippeAuf(tester, find.text('Vorlage speichern'));

    // Der Abbrechen-Knopf ist aus …
    final abbrechenKnopf = tester.widget<ElevatedButton>(
      find.ancestor(of: abbrechen, matching: find.byType(ElevatedButton)),
    );
    expect(abbrechenKnopf.onPressed, isNull);
    await tippeAuf(tester, abbrechen);
    expect(verwerfenFrage, findsNothing);

    // … und der Zurück-Pfeil der AppBar löst ebenfalls nichts aus: Die Wache
    // lässt den Pop-Versuch still verfallen, statt zu fragen.
    await tippeAuf(tester, find.byType(BackButton));
    expect(verwerfenFrage, findsNothing);
    expect(gepoppt, isFalse);
    expect(find.text('Vorlage bearbeiten'), findsOneWidget);

    // Jetzt darf das Speichern durchlaufen — und die Seite geht mit `true`.
    angehalten.freigabe.complete(vorlage);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(verwerfenFrage, findsNothing);
    expect(gepoppt, isTrue);
    expect(ergebnis, isTrue);
  });

  testWidgets('nach dem Speichern fragt die Wache nicht mehr', (tester) async {
    // Der Erfolgsweg geht bewusst über `Navigator.pop`, das `PopScope` gar
    // nicht erst fragt. Stünde dort `maybePop`, käme nach dem Speichern die
    // Verwerfen-Frage — auf etwas, das gerade gespeichert wurde.
    await oeffneEditor(tester);

    await tester.enterText(namensfeld, 'Anspruchsschreiben (neu)');
    await tester.pumpAndSettle();

    await tippeAuf(tester, find.text('Vorlage speichern'));
    // Der Bloc wartet nach dem Schreiben 200 ms, bevor er „fertig" meldet.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(verwerfenFrage, findsNothing);
    expect(gepoppt, isTrue);
    expect(ergebnis, isTrue);
  });
}
