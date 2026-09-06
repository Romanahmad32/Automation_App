import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slot_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_editor_kopf.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Anordnung der Seite „Vorlage bearbeiten" (#104 Stufe 3a) — ohne Blocs,
/// ohne Formular, ohne Vorlage.
///
/// Genau dafür ist [VorlagenEditorLayout] von der Seite getrennt: Was hier
/// geprüft wird, ist eine Frage von Breiten und Reihenfolgen, und die lässt
/// sich mit `SizedBox`en beantworten. Die Bausteine selbst haben ihre eigenen
/// Tests daneben.
///
/// Der Überlaufteil folgt dem Muster aus `felder_karte_schmal_test.dart`:
/// größte Schriftstufe (Issue #57), schmales Fenster, `takeException` muss
/// leer bleiben. Dort steht statt einer `SizedBox` echter Inhalt — eine
/// Überschrift, die mit der Schrift wächst, und zwei Knöpfe, die es auch tun.
class FesterPlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(const ['Kennzeichen', 'Zahlungsfrist']);
}

void main() {
  const kopf = ValueKey('probe_kopf');
  const knoepfe = ValueKey('probe_knoepfe');
  const name = ValueKey('probe_name');
  const links = ValueKey('probe_links');
  const felder = ValueKey('probe_felder');

  /// Was das Layout der Feldertabelle beim letzten Aufbau mitgegeben hat. Nur
  /// es kennt die Breite, also ist das die einzige Stelle, an der die
  /// Entscheidung „eigener Scrollbereich" beobachtbar wird.
  bool? bekamScrollbereich;

  Future<void> zeige(
    WidgetTester tester, {
    required Size fenster,
    Widget kopfInhalt = const SizedBox(key: kopf, width: 220, height: 40),
    Widget knopfInhalt = const SizedBox(key: knoepfe, width: 260, height: 40),
    Schriftstufe schriftstufe = Schriftstufe.normal,
  }) async {
    tester.view.physicalSize = fenster;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bekamScrollbereich = null;

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(
          body: VorlagenEditorLayout(
            kopf: kopfInhalt,
            knopfzeile: knopfInhalt,
            namensKarte: const SizedBox(key: name, height: 80),
            linkeSpalte: const [SizedBox(key: links, height: 600)],
            felder: (context, eigenerScrollbereich) {
              bekamScrollbereich = eigenerScrollbereich;
              return const SizedBox(key: felder, height: 900);
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Die echte Knopfzeile in klein: dieselbe `Row` mit denselben Abständen und
  /// denselben Aufschriften wie `FormTemplateActionButtons`, nur ohne den
  /// `FormTemplateDataBloc` dahinter. Für die Frage „passt das nebeneinander?"
  /// ist das der ganze Unterschied.
  const echteKnoepfe = Row(
    key: knoepfe,
    spacing: 15,
    children: [
      CustomRectangularButton(label: Text('Abbrechen')),
      CustomRectangularButton(label: Text('Vorlage speichern')),
    ],
  );

  final linkeSpalte = find.byKey(VorlagenEditorLayout.linkeSpalteSchluessel);
  final kopfzeile = find.byKey(VorlagenEditorLayout.kopfzeileSchluessel);

  testWidgets('ab der Schwelle stehen zwei Spalten, die linke fest breit', (
    tester,
  ) async {
    await zeige(tester, fenster: const Size(1440, 1000));

    expect(linkeSpalte, findsOneWidget);
    expect(
      tester.getSize(linkeSpalte).width,
      VorlagenEditorLayout.linkeSpalteBreite,
    );
    // Die Feldertabelle steht rechts daneben, nicht darunter.
    expect(
      tester.getTopLeft(find.byKey(felder)).dx,
      greaterThanOrEqualTo(tester.getTopRight(linkeSpalte).dx),
    );
    // Und sie scrollt für sich — das ist der Punkt der zweiten Spalte.
    expect(bekamScrollbereich, isTrue);
  });

  testWidgets('die Knöpfe stehen im Kopf, über allem anderen', (tester) async {
    await zeige(tester, fenster: const Size(1440, 1000));

    expect(
      find.descendant(of: kopfzeile, matching: find.byKey(knoepfe)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kopfzeile, matching: find.byKey(kopf)),
      findsOneWidget,
    );
    // Rechts vom Kopf, nicht darunter: Dafür steht das `spaceBetween` im Wrap.
    expect(
      tester.getTopLeft(find.byKey(knoepfe)).dx,
      greaterThan(tester.getTopRight(find.byKey(kopf)).dx),
    );
    // Über der Namenskarte — und damit über allem, was scrollt.
    expect(
      tester.getBottomLeft(find.byKey(knoepfe)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(name)).dy),
    );
  });

  testWidgets('genau auf der Schwelle reicht es noch für zwei Spalten', (
    tester,
  ) async {
    // Fensterbreite = Schwelle + Seitenrand: Gemessen wird der Platz, den die
    // Spalten bekommen, nicht das Fenster.
    final rand = VorlagenEditorLayout.seitenrand.horizontal;
    await zeige(
      tester,
      fenster: Size(VorlagenEditorLayout.zweiSpaltenAb + rand, 1000),
    );

    expect(linkeSpalte, findsOneWidget);
  });

  testWidgets('unter der Schwelle wird gestapelt, die Knöpfe bleiben oben', (
    tester,
  ) async {
    await zeige(tester, fenster: const Size(900, 1000));

    expect(linkeSpalte, findsNothing);
    // Keine verschachtelten Scrollbereiche im Stapel — die Seite scrollt.
    expect(bekamScrollbereich, isFalse);
    expect(
      tester.getBottomLeft(find.byKey(knoepfe)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(name)).dy),
    );
    // Reihenfolge im Stapel: erst die linke Spalte, dann die Feldertabelle.
    expect(
      tester.getTopLeft(find.byKey(felder)).dy,
      greaterThan(tester.getTopLeft(find.byKey(links)).dy),
    );
  });

  for (final breite in [1210.0, 1180.0, 700.0]) {
    testWidgets('läuft bei größter Schrift und $breite px nicht über', (
      tester,
    ) async {
      await zeige(
        tester,
        fenster: Size(breite, 900),
        kopfInhalt: const VorlagenEditorKopf(key: kopf, bearbeiten: true),
        knopfInhalt: echteKnoepfe,
        schriftstufe: Schriftstufe.amGroessten,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Vorlage bearbeiten'), findsOneWidget);
      expect(find.text('Vorlage speichern'), findsOneWidget);
    });
  }

  testWidgets('die Dateikarte trägt die feste Breite der linken Spalte', (
    tester,
  ) async {
    // Die breiteste Karte der linken Spalte an ihrem engsten Fall: 400 px
    // abzüglich Kartenrand, größte Schriftstufe, verknüpfte Datei (dann steht
    // neben „Andere Datei wählen" auch noch der Entfernen-Knopf).
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FesterPlatzhalter())
      ..add(
        const LoadTemplatePlaceholders(
          'HGn.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const SizedBox(
              width: VorlagenEditorLayout.linkeSpalteBreite,
              child: TemplateFileSlotCard(
                slot: TemplateFileSlot.ohneAuflistung,
                path: r'C:\Vorlagen\Anspruchsschreiben HGn.docx',
                title: 'Vorlage ohne Auflistung (HGn)',
                subtitle: 'Standardbrief mit Haftung dem Grunde nach.',
                onPick: _nichts,
                onRemove: _nichts,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Andere Datei wählen'), findsOneWidget);
    expect(find.byTooltip('Verknüpfung entfernen'), findsOneWidget);
  });
}

/// Ein Rückruf, der nichts tut — als `const` verwendbar, anders als `() {}`.
void _nichts() {}
