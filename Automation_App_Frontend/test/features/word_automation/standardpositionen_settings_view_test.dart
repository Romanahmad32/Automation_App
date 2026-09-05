import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/views/standardpositionen_settings_view.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/standardpositionen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Reiter „Schadensaufstellung": Die Titelzeilen-Farbe wohnt jetzt hier,
/// speichert beim Auswählen **für sich** (auf dem geladenen Stand, damit die
/// Kanzleidaten daneben stehen bleiben) — und die Vorschau übernimmt die
/// gewählte Farbe sofort, noch bevor das Backend geantwortet hat.
///
/// Seit Issue #106 steht hier auch der Speichern-Knopf der Standardpositionen:
/// in der Kopfzeile, gespeist aus dem Entwurf, den diese Seite hält, und beim
/// Scrollen stehenbleibend. Was der Editor darunter in den Entwurf meldet,
/// prüft `standardpositionen_editor_test.dart`.
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
  /// Merkt sich, was der Speichern-Knopf hinausgegeben hat — `null` heißt: Es
  /// wurde gar nicht gespeichert.
  List<StandardSchadensposition>? zuletztGespeichert;

  @override
  Future<List<StandardSchadensposition>> lade() async =>
      StandardSchadenspositionen.vorgabe;

  @override
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  ) async {
    zuletztGespeichert = positionen;
    return positionen;
  }
}

void main() {
  final gespeicherteSettings = KanzleiSettings.empty.copyWith(
    name: 'Kanzlei Mustermann',
    tabellenkopfFarbeHex: 'B4C6E7',
  );

  late MerkendeKanzleiSpeicherung speicherung;
  late VorgabenRepository positionen;

  Future<void> zeigeReiter(WidgetTester tester) async {
    speicherung = MerkendeKanzleiSpeicherung();
    positionen = VorgabenRepository();
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
            create: (_) => StandardpositionenCubit(positionen)..laden(),
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

  /// Nur die Felder des Editors, nicht das Farbfeld daneben: Die Reihenfolge
  /// über `find.byType(TextField)` allein hinge daran, welcher Abschnitt oben
  /// steht.
  Finder betragsfeld(int zeile) => find
      .descendant(
        of: find.byType(StandardpositionenEditor),
        matching: find.byType(TextField),
      )
      .at(zeile * 2 + 1);

  testWidgets('der Speichern-Knopf gibt die getippten Zeilen hinaus', (
    tester,
  ) async {
    await zeigeReiter(tester);

    await tester.enterText(betragsfeld(0), '1.250,75');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(
      positionen.zuletztGespeichert?.first,
      const StandardSchadensposition(
        bezeichnung: 'Reparaturkosten netto nach Gutachten',
        betrag: 1250.75,
      ),
    );
    expect(find.text('Standardpositionen gespeichert.'), findsOneWidget);
  });

  testWidgets('ein negativer Betrag sperrt den Speichern-Knopf', (
    tester,
  ) async {
    await zeigeReiter(tester);

    await tester.enterText(betragsfeld(0), '-250');
    await tester.pumpAndSettle();

    expect(find.text('Betrag darf nicht negativ sein'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(positionen.zuletztGespeichert, isNull);
  });

  testWidgets('der Speichern-Knopf steht in der Kopfzeile und bleibt beim '
      'Scrollen stehen', (tester) async {
    await zeigeReiter(tester);

    expect(
      find.text('Speichern'),
      findsOneWidget,
      reason:
          'Genau einer: Der zweite Knopf unter dem Editor ist mit Issue #106 '
          'entfallen. Zwei Speichern-Knöpfe auf einer Seite lassen niemanden '
          'raten, wo die Grenze zwischen ihnen verläuft.',
    );

    final knopfVorher = tester.getTopLeft(find.text('Speichern'));
    final inhaltVorher = tester.getTopLeft(find.text('Vorschau'));

    // Am Scrollbereich ziehen, nicht am Inhalt: Der reicht weit über das
    // Fenster hinaus, der Griff ginge sonst ins Leere.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Vorschau')).dy,
      lessThan(inhaltVorher.dy),
      reason: 'Ohne tatsächliche Bewegung sagt der Vergleich darunter nichts.',
    );
    expect(
      tester.getTopLeft(find.text('Speichern')),
      knopfVorher,
      reason:
          'Der Knopf gehört in die Kopfzeile über dem Scrollbereich. Rutscht '
          'er hinein, ist der Gewinn der Umstellung weg: Wer eine Position '
          'ändert, müsste zum Speichern an der Vorschau vorbei nach unten.',
    );
  });
}
