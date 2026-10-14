import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/letzte_aktualisierung.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_begleiter.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'aktualisierung_doubles.dart';
import 'aktualisierungs_dialog_testaufbau.dart';

/// Nach dem Neustart (#196): Rückmeldung, ob die Aktualisierung geklappt hat
/// (3b/3c), danach quittiert — und Ablehnungen des Dienstes als Fehler.
void main() {
  Future<CubitAufbau> starte(
    WidgetTester tester,
    AktualisierungRepositoryDouble repository,
  ) async {
    final aufbau = CubitAufbau(repository: repository);
    addTearDown(aufbau.cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: AktualisierungsBegleiter(
            cubit: aufbau.cubit,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return aufbau;
  }

  testWidgets('3b geklappt: Erfolg, länger als drei Sekunden, quittiert', (
    tester,
  ) async {
    const letzte = LetzteAktualisierung(
      zielVersion: '1.4.0',
      erfolgreich: true,
    );
    final aufbau = await starte(
      tester,
      AktualisierungRepositoryDouble(
        anfang: standMit(
          AktualisierungsZustand.aktuell,
          neueVersion: null,
          letzte: letzte,
        ),
      ),
    );

    const text = 'Die App wurde auf Version 1.4.0 aktualisiert.';
    expect(find.text(text), findsOneWidget);
    expect(aufbau.repository.quittungen, 1);
    expect(aufbau.repository.aufrufe, containsAllInOrder(['stand', 'pruefen']));

    await tester.pump(const Duration(seconds: 5));
    expect(find.text(text), findsOneWidget, reason: 'länger als 3 s');
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(text), findsNothing);
  });

  testWidgets('3c nicht geklappt: Fehler bleibt, „Erneut versuchen“ lädt neu', (
    tester,
  ) async {
    const letzte = LetzteAktualisierung(
      zielVersion: '1.4.0',
      erfolgreich: false,
    );
    final repository = AktualisierungRepositoryDouble(
      anfang: standMit(AktualisierungsZustand.verfuegbar, letzte: letzte),
    );
    final aufbau = await starte(tester, repository);

    const text =
        'Die Aktualisierung auf Version 1.4.0 hat nicht geklappt. Ihre Daten '
        'sind unverändert.';
    expect(find.text(text), findsOneWidget);
    expect(repository.quittungen, 1);

    await tester.pump(const Duration(minutes: 1));
    expect(find.text(text), findsOneWidget, reason: 'Fehler bleiben stehen');

    repository.downloads.add(ok(standMit(AktualisierungsZustand.laedt)));
    final vorher = repository.aufrufe.length;
    await tester.tap(
      find.byKey(AktualisierungsDialog.erneutVersuchenSchluessel),
    );
    await zeigeBild(tester);

    expect(find.text(text), findsNothing);
    expect(find.text('Version 1.4.0 wird heruntergeladen.'), findsOneWidget);
    expect(repository.aufrufe.skip(vorher), [
      'pruefen',
      'herunterladen',
    ], reason: 'prüft neu und lädt');
    expect(aufbau.cubit.state.zustand, AktualisierungsZustand.laedt);
  });

  testWidgets('ohne Ergebnis keine Rückmeldung und keine Quittung', (
    tester,
  ) async {
    final aufbau = await starte(tester, AktualisierungRepositoryDouble());

    expect(find.byType(Text), findsNothing);
    expect(aufbau.repository.quittungen, 0);
  });

  testWidgets('eine Ablehnung des Dienstes erscheint als Fehler', (
    tester,
  ) async {
    final repository = AktualisierungRepositoryDouble();
    repository.downloads.add(abgelehnt('Es ist keine neue Version bekannt.'));
    final aufbau = await starte(tester, repository);

    await aufbau.cubit.herunterladen();
    // Der Listener hört den Zustand erst im nächsten Bild.
    await tester.pump();
    await tester.pump();

    expect(find.text('Es ist keine neue Version bekannt.'), findsOneWidget);
  });
}
