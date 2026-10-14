// Durchlauf der E2E-Suite (#196): Update aus der App heraus — gegen die
// Update-Attrappe des Testmodus-Dienstes (9.9.9, kein Installer, keine Anfrage
// nach außen). Start nur über scripts/e2e-suite.ps1 — die Schranke am Anfang
// bricht gegen jeden Dienst ohne Testmodus ab.
import 'dart:convert';

import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helfer/aktualisierungs_schritte.dart';
import 'helfer/bedienung.dart';
import 'helfer/dienst_zugang.dart';
import 'helfer/e2e_umgebung.dart';
import 'helfer/testmodus_spuren.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Update aus der App: falsche Prüfsumme hält an, die richtige startet den '
    'Installer',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await E2eUmgebung.stelleTestmodusSicher();
      final spuren = TestmodusSpuren.ausUmgebung();
      final marke = spuren.stand();
      final bedienung = Bedienung(tester);
      final schritte = AktualisierungsSchritte(bedienung);

      // Gegenfall zuerst: Die Attrappe verfälscht ein Byte. Das Einstellen
      // setzt den Update-Stand des Dienstes zurück — die Suite fährt alle
      // Durchläufe gegen denselben Dienst. Vor dem Start der App, die beim
      // Start einmal prüfen lässt.
      await DienstZugang.stelleAktualisierungEin(pruefsummeFalsch: true);

      await bedienung.starteApp();
      await schritte.dialogOeffnen();
      await schritte.jetztAktualisieren();
      await bedienung.warteAuf(
        find.text(
          'Die Datei kam nicht vollständig an und wird nicht verwendet.',
        ),
        frist: AktualisierungsSchritte.ladeFrist,
        was: 'den Fehlerzustand nach der falschen Prüfsumme (2d)',
      );
      expect(
        spuren.seitMitAktion(marke, 'aktualisierung-installer'),
        isEmpty,
        reason: 'Eine verworfene Datei darf keinen Installer starten.',
      );

      // Der gute Fall: Attrappe zurückstellen, „Erneut versuchen“ prüft neu
      // und lädt, dann „Jetzt neu starten“.
      await DienstZugang.stelleAktualisierungEin(pruefsummeFalsch: false);
      await schritte.erneutVersuchen();
      await schritte.neuStarten();

      // Im Testmodus bleibt die App offen; statt des Neustarts kommt ein
      // Hinweis, und der Dialog ist zu.
      await bedienung.warteAuf(
        find.text(AktualisierungCubit.testmodusHinweis),
        was: 'den Hinweis des Testmodus statt des Neustarts',
      );
      await bedienung.warteBisWeg(
        find.text('App aktualisieren'),
        was: 'der Dialog nach „Jetzt neu starten“',
      );

      // Genau ein Installer-Aufruf, mit den Schaltern für die stille
      // Installation und den Neustart — und nie dem erzwungenen Schließen.
      final installer = spuren.seitMitAktion(marke, 'aktualisierung-installer');
      expect(installer, hasLength(1));
      final aufruf = jsonDecode(
        spuren.datei(installer.single).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(aufruf['zielVersion'], AktualisierungsSchritte.version);
      final argumente = aufruf['argumente'] as String;
      expect(argumente, contains('/SILENT'));
      expect(argumente, contains('/NEUSTART=1'));
      expect(argumente, isNot(contains('/FORCECLOSEAPPLICATIONS')));

      // Den Update-Stand zurücksetzen: Die folgenden Durchläufe starten
      // sonst mit „Update bereit“ in der Seitenleiste.
      await DienstZugang.stelleAktualisierungEin(pruefsummeFalsch: false);
    },
  );
}
