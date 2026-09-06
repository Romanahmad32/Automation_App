import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_details_page.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_name_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_dateiwahl.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_leerzustand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Ablauf „Datei zuerst" an der echten Detailseite (#104 Stufe 3c/5):
/// Eine neue Vorlage beginnt mit **einer** Aufgabe — die Word-Dateien wählen —,
/// und alles Weitere (Name, Felder) leitet die App daraus ab.
///
/// **Seit Stufe 5 bleibt die Auswahlseite stehen, bis „Weiter" gedrückt ist.**
/// Bis dahin verschwand sie mit dem ersten gesetzten Pfad; die zweite,
/// gleichwertige Datei war dann nur noch im Editor zu verknüpfen. Die
/// Erwartung „mit der Datei kommen Layout, Felder und der Namensvorschlag"
/// hängt jetzt am Klick auf „Weiter" statt an der Dateiwahl — das ist die vom
/// Anwender beauftragte Änderung, kein nachgezogener Test.
///
/// Aufbau wie in `vorlagen_verlassen_test.dart` und
/// `form_template_details_filter_test.dart`: echte Seite, echte Blocs, von
/// Hand geschriebene Fakes (dieser Testordner kennt keine Mock-Bibliothek).
/// Die Dateiwahl führt sonst in einen Plattformkanal, den ein Widget-Test
/// nicht bedienen kann, und wird über [VorlagenDateiwahl.waehle] ersetzt
/// (siehe die Begründung dort — die Seite kann sie nicht als Parameter nehmen,
/// ihr Konstruktor speist die generierte auto_route-Route).
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  /// Je Datei **andere** Platzhalter: Nur so ist zu sehen, dass die Felder
  /// beider Dateien zusammenkommen, statt dass die zweite Datei bloß die
  /// Namen der ersten wiederholt.
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(
    params.wordFilePath.contains(' SA ')
        ? const ['Summe', 'Restwert']
        : const ['Mandant', 'Frist'],
  );
}

/// Eine Platzhalter-Erkennung, die auf ihren Auftrag wartet — der Zustand, in
/// dem „Weiter" grau bleiben muss.
class WartendePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  final Completer<List<String>> antwort = Completer<List<String>>();

  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(await antwort.future);
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

void main() {
  // Die Dateinamen tragen Präfix und Suffix der Kanzleiablage; übrig bleiben
  // muss „Anspruchsschreiben" (siehe `vorlagenname_vorschlag_test.dart`).
  const ohneDatei =
      'C:/Vorlagen/VORLAGE Anspruchsschreiben ohne Auflistung.docx';
  const mitDatei =
      'C:/Vorlagen/VORLAGE Anspruchsschreiben SA mit Auflistung.docx';

  /// Was die ersetzte Dateiwahl beim nächsten Klick liefert.
  late String? naechsteDatei;

  final namensfeld = find.byWidgetPredicate(
    (widget) =>
        widget is GeneralTextField && widget.formControlName == 'templateName',
  );

  /// Beide Wahlflächen tragen denselben Knopf — auseinanderzuhalten sind sie
  /// nur über den Schlüssel ihrer Fläche (wie in `vorlagen_leerzustand_test`).
  Finder knopfIn(TemplateFileSlot slot, String aufschrift) => find.descendant(
    of: find.byKey(ValueKey(slot)),
    matching: find.widgetWithText(CustomRectangularButton, aufschrift),
  );

  /// Ob „Weiter" gedrückt werden kann. Über den Schlüssel und nicht über die
  /// Aufschrift: Gerade **grau** ist die Aussage, und ein grauer Knopf lässt
  /// sich nicht antippen.
  bool weiterAktiv(WidgetTester tester) =>
      tester
          .widget<ButtonStyleButton>(
            find.byKey(FormTemplateActionButtons.weiterSchluessel),
          )
          .onPressed !=
      null;

  Future<void> oeffneNeueVorlage(
    WidgetTester tester, {
    UseCase<List<String>, GetTemplatePlaceholdersParams>? quelle,
  }) async {
    // Die Feldzeilen sind für die 800-px-Standardfläche des Testers zu schmal.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    naechsteDatei = null;
    VorlagenDateiwahl.waehle = (context) async => naechsteDatei;
    addTearDown(VorlagenDateiwahl.zuruecksetzen);

    final platzhalter = TemplatePlaceholdersBloc(quelle ?? FestePlatzhalter());
    addTearDown(platzhalter.close);
    final daten = FormTemplateDataBloc(
      StillesErstellen(),
      StillesAktualisieren(),
    );
    addTearDown(daten.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: daten),
            BlocProvider.value(value: platzhalter),
          ],
          // Kein `formTemplate`: Das ist der Anlegen-Modus.
          child: const FormTemplateDetailsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Wählt [pfad] für [slot] — über den Knopf, den die Fläche gerade trägt.
  Future<void> waehle(
    WidgetTester tester,
    TemplateFileSlot slot,
    String pfad, {
    String aufschrift = 'Datei wählen…',
  }) async {
    naechsteDatei = pfad;
    await tester.tap(knopfIn(slot, aufschrift));
    await tester.pumpAndSettle();
  }

  Future<void> weiter(WidgetTester tester) async {
    // Erst die Meldung über die angelegten Felder abwarten: `Rueckmeldung`
    // schreibt sie ins Wurzel-Overlay **oben rechts** — genau dort, wo die
    // Knopfzeile steht, und der Klick träfe die Karte statt des Knopfes. Nach
    // fünf Sekunden geht sie von selbst (`RueckmeldungsArt.hinweis`).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(FormTemplateActionButtons.weiterSchluessel));
    await tester.pumpAndSettle();
  }

  testWidgets('eine neue Vorlage ohne Datei zeigt nur die Auswahl', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    expect(find.text('Neue Vorlage erstellen'), findsOneWidget);
    expect(find.byType(VorlagenLeerzustand), findsOneWidget);

    // Weder Name noch Felder: Beides leitet sich aus der Datei ab, und ein
    // leeres Formular daneben sähe aus, als sei etwas kaputt.
    expect(find.byType(TemplateNameCard), findsNothing);
    expect(find.byType(TemplateFieldsCard), findsNothing);

    // Speichern ist weg, Abbrechen bleibt — sonst gäbe es keinen Weg zurück.
    // „Weiter" steht da, aber grau: ohne Datei gibt es nichts, womit der
    // Editor arbeiten könnte.
    expect(find.text('Vorlage erstellen'), findsNothing);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    expect(weiterAktiv(tester), isFalse);
  });

  testWidgets('nach der ersten Wahl bleibt die Auswahl stehen', (tester) async {
    await oeffneNeueVorlage(tester);

    await waehle(tester, TemplateFileSlot.ohneAuflistung, ohneDatei);

    // Der Kern von Stufe 5: Die Seite springt **nicht** in den Editor.
    expect(find.byType(VorlagenLeerzustand), findsOneWidget);
    expect(find.byType(TemplateFieldsCard), findsNothing);

    // Die Fläche zeigt jetzt ihre Datei samt Lesestand und den Weg nach Word.
    expect(
      find.text('VORLAGE Anspruchsschreiben ohne Auflistung.docx'),
      findsOneWidget,
    );
    expect(find.text('2 Platzhalter erkannt'), findsOneWidget);
    expect(
      knopfIn(TemplateFileSlot.ohneAuflistung, 'In Word öffnen'),
      findsOneWidget,
    );

    // Und „Weiter" ist jetzt zu drücken.
    expect(weiterAktiv(tester), isTrue);
  });

  testWidgets('während eine Datei gelesen wird, bleibt „Weiter" grau', (
    tester,
  ) async {
    // Die Felder entstehen erst, wenn die Platzhalter gelesen sind. Wer
    // währenddessen weiterklickt, sähe einen leeren Editor und gleich darauf
    // eine Meldung über Felder, die er nicht angelegt hat.
    final wartend = WartendePlatzhalter();
    await oeffneNeueVorlage(tester, quelle: wartend);

    naechsteDatei = ohneDatei;
    await tester.tap(knopfIn(TemplateFileSlot.ohneAuflistung, 'Datei wählen…'));
    // Einzelne `pump`s statt `pumpAndSettle`: Der Fortschrittsring der
    // Statuszeile dreht sich endlos, und „es hat sich nichts mehr bewegt"
    // tritt deshalb nie ein. Drei Läufe — Dateiwahl, Bloc-Ereignis, Neuaufbau.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Platzhalter werden gelesen …'), findsOneWidget);
    expect(weiterAktiv(tester), isFalse);

    wartend.antwort.complete(const ['Mandant']);
    await tester.pumpAndSettle();

    expect(weiterAktiv(tester), isTrue);
  });

  testWidgets('beide Dateien nacheinander, ohne Rückfrage — dann „Weiter"', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    await waehle(tester, TemplateFileSlot.ohneAuflistung, ohneDatei);
    await waehle(tester, TemplateFileSlot.mitAuflistung, mitDatei);

    // Die Felder der ersten Datei kommen in ihr weiter vor — nichts ist
    // verloren, also darf mitten in der Auswahl keine Rückfrage aufgehen.
    expect(find.text('Datei neu eingelesen'), findsNothing);
    expect(find.byType(VorlagenLeerzustand), findsOneWidget);

    await weiter(tester);

    // Jetzt steht der Editor — mit den Feldern **beider** Dateien.
    expect(find.byType(VorlagenLeerzustand), findsNothing);
    expect(find.byType(TemplateNameCard), findsOneWidget);
    expect(find.byType(TemplateFieldsCard), findsOneWidget);
    expect(find.text('Vorlage erstellen'), findsOneWidget);
    expect(find.text('Weiter'), findsNothing);

    for (final feld in ['Mandant', 'Frist', 'Summe', 'Restwert']) {
      expect(find.text(feld), findsWidgets, reason: 'Feld $feld fehlt');
    }

    // Der Name steht im Feld, und darunter steht, woher er kommt — aus der
    // **ersten** Datei, denn was schon dasteht, gewinnt.
    expect(find.text('Anspruchsschreiben'), findsOneWidget);
    expect(
      find.text(
        'Vorschlag aus VORLAGE Anspruchsschreiben ohne Auflistung.docx'
        ' — bei Bedarf anpassen',
      ),
      findsOneWidget,
    );

    // „In Word öffnen" steht auch an den Dateikarten des Editors.
    expect(
      find.widgetWithText(CustomRectangularButton, 'In Word öffnen'),
      findsNWidgets(2),
    );
  });

  testWidgets('„Verknüpfung entfernen" macht „Weiter" wieder grau', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    await waehle(tester, TemplateFileSlot.ohneAuflistung, ohneDatei);
    expect(weiterAktiv(tester), isTrue);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
        matching: find.byTooltip('Verknüpfung entfernen'),
      ),
    );
    await tester.pumpAndSettle();

    // Die Fläche steht wieder leer da, und ohne Datei geht es nicht weiter.
    expect(find.text('Noch keine Datei gewählt'), findsNWidgets(2));
    expect(weiterAktiv(tester), isFalse);
    expect(find.byType(VorlagenLeerzustand), findsOneWidget);
  });

  testWidgets('der Hinweis verschwindet, sobald der Name geändert wird', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    await waehle(tester, TemplateFileSlot.ohneAuflistung, ohneDatei);
    await weiter(tester);

    await tester.enterText(namensfeld, 'Mahnschreiben');
    // Ein einzelnes `pump`: Tippen ändert nur die FormGroup — genau der eine
    // Neuaufbau des `ReactiveFormConsumer` muss den Hinweis wegnehmen.
    await tester.pump();

    expect(find.textContaining('Vorschlag aus'), findsNothing);
    expect(find.text('Mahnschreiben'), findsOneWidget);
  });
}
