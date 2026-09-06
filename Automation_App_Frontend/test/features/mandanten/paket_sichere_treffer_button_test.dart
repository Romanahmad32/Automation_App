import 'package:automation_app/features/mandanten/presentation/widgets/paket_sichere_treffer_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Feste Schrittzahl statt `pumpAndSettle()` — siehe
/// `paket_holen_button_test.dart` für die Begründung.
Future<void> pumpKurz(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('navigiert nicht, wenn kein sicherer Treffer gefunden wurde', (
    tester,
  ) async {
    // Kein Register-Eintrag: „sicher" verlangt genau einen Treffer im
    // Mandantenregister — ohne Register kann es den nie geben, unabhängig
    // vom Ordnernamen.
    final aufbau = MandantenTestaufbau(akten: [akte('VUnfallursache Mark')]);
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: aufbau.bloc,
            child: const PaketSichereTrefferButton(),
          ),
        ),
      ),
    );
    await pumpKurz(tester);

    await tester.tap(find.text('Sichere Treffer übernehmen'));
    await pumpKurz(tester);

    expect(
      find.text('Kein Ordner lässt sich ohne Nachlesen sicher zuordnen.'),
      findsOneWidget,
    );
  });

  // Derselbe Befund wie bei `paket_holen_button_test.dart`: der Knopf blieb
  // während des gesamten Laufs bedienbar. Hier entsteht keine falsche
  // Paketnummer (es wird keine vorhergesagt), wohl aber eine doppelte
  // Navigation bzw. ein doppelter Registerabruf — die Sperre muss beides
  // verhindern.
  testWidgets('ein Doppelklick löst den Ablauf nur einmal aus', (tester) async {
    final aufbau = MandantenTestaufbau(akten: [akte('VUnfallursache Mark')]);
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: aufbau.bloc,
            child: const PaketSichereTrefferButton(),
          ),
        ),
      ),
    );
    await pumpKurz(tester);

    // Denselben Callback zweimal unmittelbar hintereinander aufrufen statt
    // zweimal zu tippen — siehe `paket_holen_button_test.dart` für die
    // Begründung: zwischen zwei `await tester.tap(...)` liefe die
    // Microtask-Kette des ersten Laufs schon leer.
    final knopf = tester.widget<FilledButton>(find.byType(FilledButton));
    knopf.onPressed!();
    knopf.onPressed!();
    await pumpKurz(tester);

    expect(aufbau.mandantenQuelle.aufrufe, 1);
  });
}
