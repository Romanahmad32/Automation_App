import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/views/standardpositionen_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Reiter „Schadensaufstellung": Die Titelzeilen-Farbe wohnt jetzt hier,
/// speichert beim Auswählen **für sich** (auf dem geladenen Stand, damit die
/// Kanzleidaten daneben stehen bleiben) — und die Vorschau übernimmt die
/// gewählte Farbe sofort, noch bevor das Backend geantwortet hat.
class FesteKanzleiSettings implements UseCase<KanzleiSettings, NoParams> {
  FesteKanzleiSettings(this.settings);

  final KanzleiSettings settings;

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(settings);
}

class MerkendeKanzleiSpeicherung
    implements UseCase<KanzleiSettings, KanzleiSettings> {
  KanzleiSettings? zuletztGespeichert;

  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) async {
    zuletztGespeichert = params;
    return Right(params);
  }
}

class VorgabenRepository implements StandardSchadenspositionenRepository {
  @override
  Future<List<StandardSchadensposition>> lade() async =>
      StandardSchadenspositionen.vorgabe;

  @override
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  ) async => positionen;
}

void main() {
  final gespeicherteSettings = KanzleiSettings.empty.copyWith(
    name: 'Kanzlei Mustermann',
    tabellenkopfFarbeHex: 'B4C6E7',
  );

  late MerkendeKanzleiSpeicherung speicherung;

  Future<void> zeigeReiter(WidgetTester tester) async {
    speicherung = MerkendeKanzleiSpeicherung();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => KanzleiSettingsBloc(
              FesteKanzleiSettings(gespeicherteSettings),
              speicherung,
            )..add(const LoadKanzleiSettingsEvent()),
          ),
          BlocProvider(
            create: (_) =>
                StandardpositionenCubit(VorgabenRepository())..laden(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: StandardpositionenSettingsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color kopfzeilenFarbe(WidgetTester tester) {
    final tabelle = tester.widget<Table>(find.byType(Table));
    final kopf = tabelle.children.first.decoration! as BoxDecoration;
    return kopf.color!;
  }

  /// Das Befüllen des Farbfelds beim Laden ist keine Änderung. Speicherte es
  /// mit, ginge bei jedem Öffnen des Reiters ein PUT hinaus — und ein
  /// Ladefehler eines Nachbarfelds würde als alter Stand festgeschrieben.
  testWidgets('das Befüllen beim Laden speichert nichts', (tester) async {
    await zeigeReiter(tester);

    expect(find.text('Kanzlei Mustermann'), findsNothing);
    expect(speicherung.zuletztGespeichert, isNull);
    expect(kopfzeilenFarbe(tester), const Color(0xFFB4C6E7));
  });

  testWidgets('ein Klick auf ein Farbfeld speichert die Farbe für sich', (
    tester,
  ) async {
    await zeigeReiter(tester);

    await tester.tap(find.byTooltip('Grün'));
    await tester.pumpAndSettle();

    final gespeichert = speicherung.zuletztGespeichert;
    expect(gespeichert, isNotNull);
    expect(gespeichert!.tabellenkopfFarbeHex, 'C6E0B4');
    // Auf dem geladenen Stand aufgesetzt — die Kanzleidaten bleiben stehen.
    expect(gespeichert.name, 'Kanzlei Mustermann');
    expect(find.text('Tabellenfarbe gespeichert.'), findsOneWidget);
  });

  testWidgets('die Vorschau übernimmt die gewählte Farbe sofort', (
    tester,
  ) async {
    await zeigeReiter(tester);

    await tester.tap(find.byTooltip('Gelb'));
    await tester.pump();

    expect(kopfzeilenFarbe(tester), const Color(0xFFFFE699));
  });
}
