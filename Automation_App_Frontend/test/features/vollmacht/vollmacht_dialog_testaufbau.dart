import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Baut den Cubit des Vollmacht-Dialogs zu [vorgang] auf den Doubles auf und
/// bringt ihn in die Eingabe, den Drucker schon abgefragt — wahlweise danach
/// gedruckt ([drucken]) oder in Word geöffnet ([inWordOeffnen], Word lässt
/// sich anstoßen). [platzhalter] sind die, die der Vorlagenstand je Art
/// meldet; null wie ein Dienst vor #171.
///
/// Aufruf im testWidgets, nie in setUp: Sonst läuft der Cubit außerhalb der
/// Fake-Zone, und der Test wartet ewig.
Future<VollmachtCubit> baueVollmachtDialogCubit(
  WidgetTester tester, {
  required Vorgang vorgang,
  Mandant? mandant,
  Map<VollmachtArt, List<String>>? platzhalter,
  bool drucken = false,
  bool inWordOeffnen = false,
}) async {
  late VollmachtCubit cubit;
  if (inWordOeffnen) {
    DateiOeffner.oeffne = (_) async => true;
    addTearDown(DateiOeffner.zuruecksetzen);
  }
  await tester.runAsync(() async {
    final dienst = VollmachtRepositoryDouble()
      ..vorlagen = VollmachtRepositoryDouble.standMit(
        VollmachtArt.values.toSet(),
        platzhalter: platzhalter,
      );
    final mandantId = vorgang.mandantId;
    if (mandant != null && mandantId != null) {
      dienst.mandanten[mandantId] = mandant;
    }
    final vorgaenge = VollmachtVorgaengeDouble()
      ..bestand[vorgang.referenz] = vorgang;
    cubit = (await baueVollmachtCubit(dienst, vorgaenge)).cubit;
    await cubit.starte(vorgang, const []);
    await cubit.ladeDrucker();
    if (drucken) await cubit.drucke();
    if (inWordOeffnen) await cubit.oeffneInWord();
  });
  addTearDown(cubit.close);
  return cubit;
}

/// Zeigt den Dialog zu [cubit] in einem Fenster der Größe [fenster] — im
/// echten, auf „Am größten" angehobenen Theme (Issue #57).
Future<void> zeigeVollmachtDialog(
  WidgetTester tester,
  VollmachtCubit cubit, {
  Size fenster = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = fenster;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: MaterialTheme(
        ThemeData.light().textTheme,
        schriftstufe: Schriftstufe.amGroessten,
      ).light(),
      home: Scaffold(
        body: BlocProvider.value(value: cubit, child: const VollmachtDialog()),
      ),
    ),
  );
  await tester.pump();
}
