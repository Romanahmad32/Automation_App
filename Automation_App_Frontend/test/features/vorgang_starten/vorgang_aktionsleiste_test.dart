import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_aktionsleiste.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'vorgang_starten_doubles.dart';

/// Die Aktionsleiste steht bei Verkehrsrecht mit zwei Knöpfen in einer `Row`
/// ohne `Wrap`/`Flexible` ("Zentralruf-Formular ausfüllen" + "Vorgang
/// speichern"). Bei "Am größten" (Issue #57) sind die Beschriftungen deutlich
/// breiter, und auf einem schmalen Fenster (~700 px) reicht der Platz nicht
/// mehr für beide Knöpfe nebeneinander — die Zeile läuft rechts über.
void main() {
  Future<void> zeigeLeiste(
    WidgetTester tester, {
    required double breite,
  }) async {
    final bloc = VorgangStartenBloc(
      FesterZentralrufPrefill(
        const ZentralrufPrefillResult(
          referenz: '1/26 C03',
          filledFields: [],
          skippedFields: [],
        ),
      ),
      OhneKanzleiEinstellungen(),
      MandantAnlegenDouble(MandantenRegisterDouble()),
      MandantAktualisierenDouble(MandantenRegisterDouble()),
      VorgangCubit(VorgangAblageDouble(), VorgangPersistenzFehlerCubit()),
    );
    addTearDown(bloc.close);
    final formular = createVorgangForm();

    tester.view.physicalSize = Size(breite, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
        // bliebe der Test blind für den gemeldeten Überlauf.
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formular,
              child: VorgangAktionsleiste(
                zeigeZentralruf: true,
                onSpeichern: () {},
                onZentralruf: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'die Aktionsleiste mit beiden Knoepfen laeuft bei "Am groessten" und '
    'schmalem Fenster nicht ueber',
    (tester) async {
      await zeigeLeiste(tester, breite: 700);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die Knöpfe "Zentralruf-Formular ausfüllen" und "Vorgang '
            'speichern" standen in einer Row ohne Wrap/Flexible — bei "Am '
            'größten" und schmalem Fenster lief die Zeile rechts über.',
      );
    },
  );
}
