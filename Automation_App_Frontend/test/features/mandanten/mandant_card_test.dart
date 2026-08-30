import 'package:automation_app/features/mandanten/presentation/widgets/mandant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

void main() {
  // Die Karte ist rund, die Tippfläche des ExpansionTile darunter nicht: ohne
  // Zutun zeichnet der Hover-Effekt rechteckig und steht über die Ecken der
  // Karte hinaus. Ein Widget-Test kann das Bild nicht sehen, wohl aber die
  // beiden Angaben, an denen es hängt — und die verschwinden leicht wieder.
  testWidgets('die Karte schneidet den Hover-Effekt an ihrer Rundung', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      register: [mandant(1, 'Mustermann')],
      akten: [akte('VUnfallursache Mark')],
    );
    addTearDown(aufbau.close);
    final geladen = await aufbau.laden();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: aufbau.bloc,
            child: MandantCard(
              mandant: geladen.mandanten.single,
              state: geladen,
            ),
          ),
        ),
      ),
    );

    final karte = tester.widget<Card>(find.byType(Card));
    expect(
      karte.clipBehavior,
      isNot(Clip.none),
      reason:
          'Ohne Clip zeichnet die Ink-Fläche des ExpansionTile in die '
          'abgerundeten Ecken der Karte hinein.',
    );

    // Auf- und zugeklappt sind zwei Parameter — der zweite wird gern vergessen.
    final kachel = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(kachel.shape, MandantCard.kartenForm);
    expect(kachel.collapsedShape, MandantCard.kartenForm);
  });
}
