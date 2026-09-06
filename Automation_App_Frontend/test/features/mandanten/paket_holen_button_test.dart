import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/paket_holen_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

Widget seite(
  MandantenOverviewBloc bloc, {
  required Future<String?> Function(String) speichernUnter,
}) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: bloc,
      child: PaketHolenButton(speichernUnter: speichernUnter),
    ),
  ),
);

/// Feste Schrittzahl statt `pumpAndSettle()` — ein zweiter Sicherheitsnetz
/// zusätzlich zur Clipboard-Attrappe unten: so bleibt der Test auch dann
/// endlich, wenn irgendein Frame einmal nicht zur Ruhe kommt.
Future<void> pumpKurz(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // `schreibeUndVerbucheArbeitspaket` legt die Anleitung per
  // `Clipboard.setData` ab. Ohne Attrappe geht der Aufruf über den echten
  // `SystemChannels.platform`-Kanal — auf manchen Läufen hat das im
  // `flutter_tester` (kein eigenes Fenster, kein Zwischenablage-Eigentümer)
  // **nie geantwortet**, und genau das hat den Testlauf zehn Minuten lang
  // hängen lassen (Befund des Masters). Die Attrappe beantwortet den Aufruf
  // synchron und lässt echte Zwischenablage-Zugriffe außen vor.
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      });

  testWidgets('verbucht nicht, wenn der Speichern-Dialog abgebrochen wird', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [akte('VUnfallursache Mark'), akte('VUnfallursache Anna')],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(
      seite(aufbau.bloc, speichernUnter: (_) async => null),
    );
    await pumpKurz(tester);

    await tester.tap(find.text('Arbeitspaket holen'));
    await pumpKurz(tester);

    expect(aufbau.arbeitspaketDatei.schreibAufrufe, 0);
    expect(aufbau.paketeSpeicher.notiereAufrufe, 0);
  });

  testWidgets('schreibt und verbucht, wenn ein Zielpfad gewählt wurde', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [akte('VUnfallursache Mark'), akte('VUnfallursache Anna')],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(
      seite(
        aufbau.bloc,
        speichernUnter: (_) async => 'C:/Ablage/arbeitspaket-1.json',
      ),
    );
    await pumpKurz(tester);

    await tester.tap(find.text('Arbeitspaket holen'));
    await pumpKurz(tester);

    expect(aufbau.arbeitspaketDatei.schreibAufrufe, 1);
    expect(aufbau.paketeSpeicher.notiereAufrufe, 1);
    expect(
      find.textContaining('gespeichert. Die Anleitung liegt in der'),
      findsOneWidget,
    );
  });

  // Befund aus dem Code Review zu Issue #108: Der Knopf blieb während des
  // gesamten Laufs bedienbar, und die Paketnummer im Dateinamen ist nur eine
  // Vorhersage (vergeben wird sie erst vom Backend). Zwei überlappende Läufe
  // schrieben deshalb beide dieselbe Nummer. Ohne Sperre löste dieser Test
  // zwei Schreib- und Verbuchungsaufrufe aus statt eines.
  testWidgets('ein Doppelklick löst den Ablauf nur einmal aus', (tester) async {
    final aufbau = MandantenTestaufbau(akten: [akte('VUnfallursache Mark')]);
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(
      seite(
        aufbau.bloc,
        speichernUnter: (_) async => 'C:/Ablage/arbeitspaket-1.json',
      ),
    );
    await pumpKurz(tester);

    // Denselben Callback zweimal unmittelbar hintereinander aufrufen statt
    // zweimal zu tippen: Zwischen zwei `await tester.tap(...)` liefe die
    // Microtask-Kette des ersten Laufs bereits leer (die Fakes lösen sofort
    // auf), und die Sperre wäre schon wieder offen, bevor der zweite Tipp
    // ankäme. Ohne `await` dazwischen bleibt kein Zeitfenster dafür — genau
    // der Doppelklick, den die Sperre in `_holen` selbst abfangen muss.
    final knopf = tester.widget<FilledButton>(find.byType(FilledButton));
    knopf.onPressed!();
    knopf.onPressed!();
    await pumpKurz(tester);

    expect(aufbau.arbeitspaketDatei.schreibAufrufe, 1);
    expect(aufbau.paketeSpeicher.notiereAufrufe, 1);
  });

  testWidgets(
    'zeigt einen Hinweis statt eines Dialogs, wenn kein Ordner mehr offen ist',
    (tester) async {
      final aufbau = MandantenTestaufbau(akten: const []);
      addTearDown(aufbau.close);
      await aufbau.laden();

      var dialogGeoeffnet = false;
      await tester.pumpWidget(
        seite(
          aufbau.bloc,
          speichernUnter: (_) async {
            dialogGeoeffnet = true;
            return null;
          },
        ),
      );
      await pumpKurz(tester);

      await tester.tap(find.text('Arbeitspaket holen'));
      await pumpKurz(tester);

      expect(dialogGeoeffnet, isFalse);
      expect(
        find.text(
          'Alle Ordner sind zugeordnet oder vermerkt — kein Paket nötig.',
        ),
        findsOneWidget,
      );
    },
  );
}
