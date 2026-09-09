import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/views/vorgang_starten_form_view.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/auftrag_section.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../sachgebiete/sachgebiet_test_katalog.dart';
import 'vorgang_starten_doubles.dart';

/// Das Rechtsgebiet folgt der Abteilung (§7.1) — und was daran hängt, folgt mit.
///
/// Vorher waren es zwei gleichrangige Auswahllisten aus **demselben** Katalog,
/// ohne Verbindung: Wer die Abteilung auf `C05` stellte, behielt
/// „Verkehrsrecht". Das war nicht nur eine doppelte Eingabe, sondern eine, die
/// auseinanderläuft — mit einer falschen Zeile im Register (§6.2),
/// Pflicht-Unfallfeldern und einem Kennzeichen in der Referenz (§4.2), das
/// dort nichts zu suchen hat. Deshalb prüfen die Tests die Ableitung nie
/// allein, sondern immer samt ihren Folgen.
void main() {
  /// Das Rechtsgebiet, wie die Auftrag-Karte es gerade führt.
  String rechtsgebiet(WidgetTester tester) =>
      tester.widget<AuftragSection>(find.byType(AuftragSection)).rechtsgebiet;

  bool folgtNichtMehr(WidgetTester tester) => tester
      .widget<AuftragSection>(find.byType(AuftragSection))
      .rechtsgebietManuell;

  FormGroup formular(WidgetTester tester) =>
      tester.widget<ReactiveForm>(find.byType(ReactiveForm)).formGroup;

  /// Baut das Formular mit dem Testkatalog (C03 Verkehrsrecht, C05 Strafrecht).
  ///
  /// Bloc und Cubit entstehen **hier** und nicht in `setUp`: Was dort gebaut
  /// wird, hängt an der echten Ereignisschleife statt an der Testuhr von
  /// `testWidgets`.
  Future<void> zeigeFormular(WidgetTester tester) async {
    final register = MandantenRegisterDouble();
    final vorgaenge = VorgangCubit(
      VorgangAblageDouble(),
      VorgangPersistenzFehlerCubit(),
    );
    final bloc = VorgangStartenBloc(
      FesterZentralrufPrefill(
        const ZentralrufPrefillResult(
          referenz: '84/26 C03',
          filledFields: [],
          skippedFields: [],
        ),
      ),
      OhneKanzleiEinstellungen(),
      MandantAnlegenDouble(register),
      MandantAktualisierenDouble(register),
      vorgaenge,
    );
    getIt.registerSingleton<UseCase<List<Mandant>, NoParams>>(
      MandantenListeDouble(register),
    );
    getIt.registerSingleton<VorgangCubit>(vorgaenge);
    registriereSachgebietKatalog();
    addTearDown(() => getIt.reset());

    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const VorgangStartenFormView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Setzt die Abteilung so, wie es die Auswahl darüber tut: über das Control.
  Future<void> setzeAbteilung(WidgetTester tester, String kuerzel) async {
    formular(tester).control('abteilung').updateValue(kuerzel);
    await tester.pumpAndSettle();
  }

  testWidgets('die Abteilung bringt ihr Rechtsgebiet mit — samt Unfallteil '
      'und Referenz', (tester) async {
    await zeigeFormular(tester);
    formular(tester).control('auftragsnummer').updateValue('84');
    formular(tester).control('kennzeichenGegner').updateValue('GG-XY 123');
    await tester.pumpAndSettle();

    // Vorbelegung C03: Verkehrsrecht, mit allem, was daran hängt.
    expect(rechtsgebiet(tester), 'Verkehrsrecht');
    expect(find.text('Unfall'), findsOneWidget);
    expect(formular(tester).control('referenz').value, '84/26 C03_GG-XY 123');

    await setzeAbteilung(tester, 'C05');

    expect(rechtsgebiet(tester), 'Strafrecht');
    // Ohne Verkehrsrecht kein Unfallteil, keine Pflicht auf dem Unfalltag —
    // und kein Kennzeichen in der Referenz.
    expect(find.text('Unfall'), findsNothing);
    expect(formular(tester).control('schadentag').valid, isTrue);
    expect(formular(tester).control('referenz').value, '84/26 C05');
  });

  testWidgets('die Überschneidung C05/3 zählt zum Hauptsachgebiet', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await setzeAbteilung(tester, 'C05/3');

    expect(rechtsgebiet(tester), 'Strafrecht');
  });

  testWidgets('eine Abteilung ausserhalb des Katalogs lässt das Rechtsgebiet '
      'stehen, statt es zu raten', (tester) async {
    await zeigeFormular(tester);
    await setzeAbteilung(tester, 'C99');

    expect(rechtsgebiet(tester), 'Verkehrsrecht');
  });

  testWidgets('„Abweichend wählen" friert das Rechtsgebiet ein, der '
      'Rückweg taut es wieder auf', (tester) async {
    await zeigeFormular(tester);

    await tester.tap(find.text('Abweichend wählen'));
    await tester.pumpAndSettle();
    expect(folgtNichtMehr(tester), isTrue);

    // Ab hier gilt die Wahl des Anwalts — auch gegen eine andere Abteilung.
    await setzeAbteilung(tester, 'C05');
    expect(
      rechtsgebiet(tester),
      'Verkehrsrecht',
      reason: 'Eine von Hand getroffene Wahl darf nicht überschrieben werden',
    );

    await tester.tap(find.byTooltip('Wieder dem Hauptsachgebiet C05 folgen'));
    await tester.pumpAndSettle();

    expect(folgtNichtMehr(tester), isFalse);
    expect(rechtsgebiet(tester), 'Strafrecht');
  });
}
