import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_datei_kachel.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_leerzustand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Auswahlseite einer neuen Vorlage (#104, Stufe 3b/5): „Womit fängt diese
/// Vorlage an?"
///
/// Geprüft wird vor allem die Gleichwertigkeit der beiden Word-Dateien — beide
/// Wahlflächen gleich groß, beide mit demselben Knopf — und dass auf einem
/// schmalen Fenster nichts überläuft (Issue #57). Was **in** einer Fläche
/// steht, prüft `vorlagen_datei_kachel_test.dart`.
///
/// Neu seit Stufe 5: Die Seite bleibt stehen, bis „Weiter" gedrückt ist, und
/// die Flächen tragen deshalb den Stand ihrer Datei. Dafür braucht der
/// Leerzustand jetzt den `TemplatePlaceholdersBloc` — er horcht einmal für
/// beide Flächen — und den Stand des Editors (`VorlagenBearbeitung`) für die
/// Pfade.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(
    params.wordFilePath.contains('SA')
        ? const ['Summe', 'Restwert']
        : const ['Mandant', 'Frist'],
  );
}

void main() {
  late List<TemplateFileSlot> gewaehlt;
  late List<TemplateFileSlot> entfernt;

  setUp(() {
    gewaehlt = [];
    entfernt = [];
  });

  /// Baut den Leerzustand in [breite] auf — mit den Pfaden, die [pfade]
  /// nennt, und einem Bloc, der ihre Platzhalter schon gelesen hat.
  Future<void> zeige(
    WidgetTester tester,
    double breite, {
    Map<TemplateFileSlot, String> pfade = const {},
    Schriftstufe schriftstufe = Schriftstufe.vorgabe,
  }) async {
    final bearbeitung = VorlagenBearbeitung.fuer(null);
    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter());
    addTearDown(bloc.close);
    for (final eintrag in pfade.entries) {
      bearbeitung.setzePfad(eintrag.key, eintrag.value);
      bloc.add(LoadTemplatePlaceholders(eintrag.value, eintrag.key));
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: breite,
                  child: VorlagenLeerzustand(
                    bearbeitung: bearbeitung,
                    onDateiWaehlen: gewaehlt.add,
                    onDateiEntfernen: entfernt.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Zwei Läufe: einer für die Antwort des Blocs, einer für den Neuaufbau.
    await tester.pump();
    await tester.pump();
  }

  /// Der Knopf **in** einer der beiden Flächen — beide tragen dieselbe
  /// Aufschrift, auseinanderzuhalten sind sie nur über den Schlüssel ihrer
  /// Fläche.
  Finder knopfIn(
    TemplateFileSlot slot, [
    String aufschrift = 'Datei wählen…',
  ]) => find.descendant(
    of: find.byKey(ValueKey(slot)),
    matching: find.widgetWithText(CustomRectangularButton, aufschrift),
  );

  testWidgets('beide Wahlflächen führen zu ihrem eigenen Slot', (tester) async {
    await zeige(tester, 900);

    expect(find.text('Womit fängt diese Vorlage an?'), findsOneWidget);
    expect(find.text('Ohne Schadensaufstellung (HGn)'), findsOneWidget);
    expect(find.text('Mit Schadensaufstellung'), findsOneWidget);
    // Derselbe Knopf an beiden Flächen — keine ist die zweite oder optionale.
    expect(find.text('Datei wählen…'), findsNWidgets(2));

    await tester.tap(knopfIn(TemplateFileSlot.ohneAuflistung));
    await tester.tap(knopfIn(TemplateFileSlot.mitAuflistung));

    expect(gewaehlt, [
      TemplateFileSlot.ohneAuflistung,
      TemplateFileSlot.mitAuflistung,
    ]);
  });

  testWidgets('nebeneinander sind beide Flächen gleich groß', (tester) async {
    // Die beiden Word-Dateien sind gleichwertig; eine größere Fläche läse sich
    // als „die richtige".
    await zeige(tester, 900);

    final ohne = tester.getSize(
      find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
    );
    final mit = tester.getSize(
      find.byKey(const ValueKey(TemplateFileSlot.mitAuflistung)),
    );

    expect(ohne, mit);
  });

  testWidgets('beide Flächen erklären, wofür ihre Datei da ist', (
    tester,
  ) async {
    await zeige(tester, 900);

    expect(find.text('Anspruchsschreiben ohne Positionsliste'), findsOneWidget);
    expect(
      find.text('Anspruchsschreiben mit {{Schadensaufstellung}}-Tabelle'),
      findsOneWidget,
    );
    // Die Fußzeile sagt beides: eine genügt, und keine ist die wichtigere.
    expect(find.textContaining('beide sind gleichwertig'), findsOneWidget);
  });

  testWidgets('die gewählte Datei bleibt auf der Auswahlseite sichtbar', (
    tester,
  ) async {
    // Der Kern von Stufe 5: Nach der ersten Wahl springt die Seite **nicht**
    // in den Editor — die zweite, gleichwertige Datei will an derselben Stelle
    // verknüpft werden.
    await zeige(
      tester,
      900,
      pfade: const {TemplateFileSlot.ohneAuflistung: 'C:/V/HGn.docx'},
    );

    expect(find.byType(VorlagenDateiKachel), findsNWidgets(2));
    expect(find.text('HGn.docx'), findsOneWidget);
    expect(find.text('2 Platzhalter erkannt'), findsOneWidget);
    expect(
      knopfIn(TemplateFileSlot.ohneAuflistung, 'In Word öffnen'),
      findsOneWidget,
    );

    // Die andere Fläche steht unverändert daneben und wartet.
    expect(knopfIn(TemplateFileSlot.mitAuflistung), findsOneWidget);
  });

  testWidgets('„Verknüpfung entfernen" meldet den eigenen Slot', (
    tester,
  ) async {
    await zeige(
      tester,
      900,
      pfade: const {TemplateFileSlot.mitAuflistung: 'C:/V/SA.docx'},
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(TemplateFileSlot.mitAuflistung)),
        matching: find.byTooltip('Verknüpfung entfernen'),
      ),
    );

    expect(entfernt, [TemplateFileSlot.mitAuflistung]);
    expect(gewaehlt, isEmpty);
  });

  testWidgets('auf 500 px läuft nichts über — die Flächen stapeln sich', (
    tester,
  ) async {
    await zeige(tester, 500);

    // Ein Überlauf liesse den Test schon beim Aufbau fallen; hier steht die
    // Gegenprobe, dass die Flächen wirklich untereinander liegen und beide
    // bedienbar bleiben.
    final ohne = tester.getTopLeft(
      find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
    );
    final mit = tester.getTopLeft(
      find.byKey(const ValueKey(TemplateFileSlot.mitAuflistung)),
    );
    expect(mit.dy, greaterThan(ohne.dy));
    expect(mit.dx, ohne.dx);

    await tester.tap(knopfIn(TemplateFileSlot.mitAuflistung));
    expect(gewaehlt, [TemplateFileSlot.mitAuflistung]);
  });

  testWidgets('zwei lange Dateinamen laufen auch am Umbruchrand nicht über', (
    tester,
  ) async {
    // Der teuerste Fall: gerade noch zweispaltig
    // (`VorlagenLeerzustand.zweispaltigAb`), beide Flächen mit Dateinamen,
    // Lesezahl und drei Knöpfen, und dazu die größte Schriftstufe (#57). Ein
    // Überlauf wirft hier beim Aufbau — `takeException` fängt ihn.
    await zeige(
      tester,
      VorlagenLeerzustand.zweispaltigAb,
      schriftstufe: Schriftstufe.amGroessten,
      pfade: const {
        TemplateFileSlot.ohneAuflistung:
            r'C:\Kanzlei\Vorlagen\VORLAGE Anspruchsschreiben ohne '
            r'Schadensaufstellung HGn Stand 2026.docx',
        TemplateFileSlot.mitAuflistung:
            r'C:\Kanzlei\Vorlagen\VORLAGE Anspruchsschreiben mit '
            r'Schadensaufstellung SA Stand 2026.docx',
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(VorlagenDateiKachel), findsNWidgets(2));
  });

  testWidgets('das Klickziel ist mindestens 32 px hoch', (tester) async {
    await zeige(tester, 900);

    final knopf = tester.getSize(knopfIn(TemplateFileSlot.ohneAuflistung));
    expect(knopf.height, greaterThanOrEqualTo(32));
  });
}
