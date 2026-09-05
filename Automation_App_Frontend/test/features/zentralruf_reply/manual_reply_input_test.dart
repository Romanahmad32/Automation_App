import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/manual_reply_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wird in diesem Test nie aufgerufen — es geht nur um die Knopfzeile unter
/// dem Eingabefeld, nicht um das Auswerten selbst.
class _NieAufgerufenesAuswerten
    implements UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput> {
  @override
  Future<Either<Failure, ZentralrufReplyParseResult>> call(
    ZentralrufReplyInput params,
  ) => throw UnimplementedError();
}

/// Die Knopfzeile unter dem Eingabefeld ("Aus Datei laden", "Aus
/// Zwischenablage", "Daten extrahieren") lief bei „Am größten" (Issue #57)
/// auf einem schmalen Fenster rechts über: eine `Row` ohne `Wrap`/`Expanded`
/// — der `Spacer` davor verhindert das nicht, er verteilt nur überschüssigen
/// Platz, lässt aber keinen der drei Knöpfe schrumpfen.
void main() {
  Future<void> zeigePanel(WidgetTester tester, {required double breite}) async {
    final bloc = ZentralrufReplyBloc(_NieAufgerufenesAuswerten());
    addTearDown(bloc.close);

    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<ZentralrufReplyBloc>.value(
        value: bloc,
        child: MaterialApp(
          // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
          // bliebe der Test blind für den gemeldeten Überlauf.
          theme: MaterialTheme(
            ThemeData.light().textTheme,
            schriftstufe: Schriftstufe.amGroessten,
          ).light(),
          home: const Scaffold(body: ManualReplyInput()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'die Knopfzeile unter dem Eingabefeld laeuft bei "Am groessten" und '
    'schmalem Fenster nicht ueber',
    (tester) async {
      await zeigePanel(tester, breite: 480);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die Knöpfe "Aus Datei laden", "Aus Zwischenablage" und "Daten '
            'extrahieren" standen in einer Row ohne Wrap/Expanded — bei "Am '
            'größten" und schmalem Fenster lief die Zeile rechts über.',
      );
    },
  );
}
