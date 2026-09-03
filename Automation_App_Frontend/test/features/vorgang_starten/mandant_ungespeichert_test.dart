import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'vorgang_starten_doubles.dart';

/// Der Mandant ist erfasst, der Vorgang wird gestartet — und gespeichert wurde
/// der Mandant nie. Der Schritt, dessen Vergessen als einziger Datenverlust
/// bedeutet, hatte die zurückhaltendste Anzeige der Seite: Der Knopf am
/// Kartenende wurde lediglich *aktiv*, und dass etwas offen ist, stand nirgends.
///
/// Geprüft wird deshalb beides zusammen — Hinweiszeile, Rand der Karte und
/// Bauform des Knopfes hängen an derselben Bedingung und dürfen nicht
/// auseinanderlaufen. Und die Gegenrichtung mit: Betonung, die immer da ist,
/// betont nichts, also muss die ruhige Karte nachweislich ruhig bleiben.
void main() {
  const hinweis = 'Ungespeicherte Änderungen am Mandanten';

  late FormGroup formular;

  Mandant max() => Mandant(
    id: 7,
    vorname: 'Max',
    nachname: 'Müller',
    strasseHausnummer: 'Hauptstr. 1',
    kennzeichen: const ['HG-E 1427'],
    erstelltAm: DateTime(2026),
  );

  /// Baut die Mandanten-Karte für sich allein — mit dem echten App-Theme, damit
  /// der hervorgehobene Rand aus derselben Kartenform entsteht wie im Betrieb.
  ///
  /// Der Bloc entsteht **hier** und nicht in `setUp`: Was dort gebaut wird,
  /// hängt an der echten Ereignisschleife statt an der Testuhr von
  /// `testWidgets`.
  Future<void> zeigeKarte(
    WidgetTester tester, {
    List<Mandant> mandanten = const [],
    int? gewaehlt,
  }) async {
    final register = MandantenRegisterDouble();
    final bloc = VorgangStartenBloc(
      FesterZentralrufPrefill(
        const ZentralrufPrefillResult(
          referenz: '1/26 C03',
          filledFields: [],
          skippedFields: [],
        ),
      ),
      OhneKanzleiEinstellungen(),
      MandantAnlegenDouble(register),
      MandantAktualisierenDouble(register),
      VorgangCubit(VorgangAblageDouble(), VorgangPersistenzFehlerCubit()),
    );
    formular = createVorgangForm();

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(const TextTheme()).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formular,
              child: SingleChildScrollView(
                child: MandantSection(
                  mandanten: mandanten,
                  selectedMandantId: gewaehlt,
                  rechtsgebiet: RechtsgebietWert.verkehrsrecht,
                  onMandantGewaehlt: (_) {},
                  onAuswahlAufheben: () {},
                  onKennzeichenGewaehlt: (_) {},
                  onMandantBestaetigt: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Schreibt Werte ins Formular und lässt die Karte darauf reagieren.
  ///
  /// **Zwei** Frames: `updateValue` meldet den neuen Wert über einen Stream,
  /// den der `ReactiveFormConsumer` erst im Microtask nach dem ersten Frame
  /// hört. Mit einem einzigen `pump` prüft der Test den Stand von vorher — und
  /// wird dann grün, weil beim verknüpften Mandanten von Anfang an eine
  /// Abweichung dasteht.
  Future<void> tippe(WidgetTester tester, Map<String, String> werte) async {
    werte.forEach((name, wert) => formular.control(name).updateValue(wert));
    await tester.pump();
    await tester.pump();
  }

  Card karte(WidgetTester tester) => tester.widget<Card>(
    find.ancestor(of: find.text('Mandant'), matching: find.byType(Card)),
  );

  /// Der Rand, den die Karte selbst setzt — `null`, solange sie das Aussehen
  /// aus dem `cardTheme` behält und damit aussieht wie jede andere Karte.
  BorderSide? kartenrand(WidgetTester tester) {
    final rahmen = karte(tester).shape;
    return rahmen is RoundedRectangleBorder ? rahmen.side : null;
  }

  Color akzent(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(MandantSection))).colorScheme.primary;

  testWidgets('bleibt ruhig, solange es nichts zu speichern gibt', (
    tester,
  ) async {
    await zeigeKarte(tester);

    expect(find.text(hinweis), findsNothing);
    expect(karte(tester).shape, isNull);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('macht einen frei erfassten Mandanten sichtbar', (tester) async {
    await zeigeKarte(tester);

    await tippe(tester, {'mandantVorname': 'Anna', 'mandantNachname': 'Klein'});

    expect(find.text(hinweis), findsOneWidget);
    expect(kartenrand(tester)?.color, akzent(tester));
    expect(
      find.widgetWithText(FilledButton, 'Neuen Mandanten speichern'),
      findsOneWidget,
    );
  });

  testWidgets('macht geänderte Daten am verknüpften Mandanten sichtbar', (
    tester,
  ) async {
    await zeigeKarte(tester, mandanten: [max()], gewaehlt: 7);

    await tippe(tester, {
      'mandantVorname': 'Max',
      'mandantNachname': 'Müller',
      'mandantStrasse': 'Hauptstr. 1',
      'mandantOrt': 'Frankfurt',
    });

    expect(find.text(hinweis), findsOneWidget);
    expect(kartenrand(tester)?.color, akzent(tester));
    expect(
      find.widgetWithText(FilledButton, 'Mandantendaten aktualisieren'),
      findsOneWidget,
    );
  });

  testWidgets('bleibt ruhig, wenn der Mandant unverändert übernommen ist', (
    tester,
  ) async {
    await zeigeKarte(tester, mandanten: [max()], gewaehlt: 7);

    await tippe(tester, {
      'mandantVorname': 'Max',
      'mandantNachname': 'Müller',
      'mandantStrasse': 'Hauptstr. 1',
      'mandantKennzeichen': 'HG-E 1427',
    });

    expect(find.text(hinweis), findsNothing);
    expect(karte(tester).shape, isNull);
    expect(find.byType(FilledButton), findsNothing);
  });

  /// Ein unlesbares Feld sperrt den Knopf, ändert aber nichts daran, dass
  /// Eingaben nur im Formular stehen. Verschwände der Hinweis mit dem gesperrten
  /// Knopf, wäre die Karte genau dann still, wenn etwas zu tun ist.
  testWidgets('sagt es auch, wenn der Knopf wegen eines Feldfehlers sperrt', (
    tester,
  ) async {
    await zeigeKarte(tester);

    await tippe(tester, {
      'mandantVorname': 'Anna',
      'mandantNachname': 'Klein',
      'mandantEmail': 'anna@',
    });

    expect(find.text(hinweis), findsOneWidget);
    final knopf = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Neuen Mandanten speichern'),
    );
    expect(knopf.onPressed, isNull);
  });
}
