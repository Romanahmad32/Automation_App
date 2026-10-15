import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_stand_zeile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';

/// Der Satz „ob es eine neuere Version gibt“ im Zustand `unbekannt` (#199):
/// Trägt der Stand eine Meldung des Dienstes, steht sie da — sonst der feste
/// Satz zur Internetverbindung.
void main() {
  Future<void> zeige(WidgetTester tester, AktualisierungsAnsicht ansicht) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AktualisierungsStandZeile(ansicht: ansicht)),
        ),
      );

  const ausgelastet =
      'Ob es eine neue Version gibt, ließ sich gerade nicht prüfen — der '
      'Update-Server ist im Moment ausgelastet. Die App sieht beim nächsten '
      'Start wieder nach und funktioniert unverändert weiter.';
  const keineVerbindung =
      'Ob es eine neue Version gibt, ließ sich gerade nicht prüfen — '
      'vermutlich besteht keine Verbindung ins Internet. Die App '
      'funktioniert unverändert weiter.';

  testWidgets('Ratenlimit: die Meldung des Dienstes steht da, nicht doppelt', (
    tester,
  ) async {
    await zeige(
      tester,
      AktualisierungsAnsicht(
        stand: standMit(
          AktualisierungsZustand.unbekannt,
          neueVersion: null,
          meldung: ausgelastet,
        ),
      ),
    );

    expect(find.text(ausgelastet), findsOneWidget);
    expect(find.text(AktualisierungsStandZeile.nichtNachgesehen), findsNothing);
  });

  testWidgets('keine Verbindung mit Meldung: nur diese, kein zweiter Satz', (
    tester,
  ) async {
    await zeige(
      tester,
      AktualisierungsAnsicht(
        stand: standMit(
          AktualisierungsZustand.unbekannt,
          neueVersion: null,
          meldung: keineVerbindung,
        ),
      ),
    );

    expect(find.text(keineVerbindung), findsOneWidget);
    expect(find.text(AktualisierungsStandZeile.nichtNachgesehen), findsNothing);
  });

  testWidgets('Dienst stumm, keine Meldung: der bisherige feste Satz', (
    tester,
  ) async {
    await zeige(tester, const AktualisierungsAnsicht(dienstStumm: true));

    expect(
      find.text(AktualisierungsStandZeile.nichtNachgesehen),
      findsOneWidget,
    );
  });

  testWidgets('Dienst stumm trotz alter Meldung: der feste Satz', (
    tester,
  ) async {
    await zeige(
      tester,
      AktualisierungsAnsicht(
        dienstStumm: true,
        stand: standMit(
          AktualisierungsZustand.unbekannt,
          neueVersion: null,
          meldung: ausgelastet,
        ),
      ),
    );

    expect(
      find.text(AktualisierungsStandZeile.nichtNachgesehen),
      findsOneWidget,
    );
    expect(find.text(ausgelastet), findsNothing);
  });
}
