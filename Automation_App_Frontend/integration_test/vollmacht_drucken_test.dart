// Durchlauf 2 der E2E-Suite (#184): Vollmacht zu einem Vorgang drucken.
// Start nur über scripts/e2e-suite.ps1 — die Schranke am Anfang bricht gegen
// jeden Dienst ohne Testmodus ab; gedruckt wird dann von der Druck-Attrappe.
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog_knoepfe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helfer/bedienung.dart';
import 'helfer/dienst_zugang.dart';
import 'helfer/e2e_umgebung.dart';
import 'helfer/lauf_kennung.dart';
import 'helfer/testmodus_spuren.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Vollmacht aus der Vorgangsliste drucken: Druck-Kopie und Vermerk',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await E2eUmgebung.stelleTestmodusSicher();
      final spuren = TestmodusSpuren.ausUmgebung();
      final marke = spuren.stand();
      final lauf = LaufKennung.jetzt();
      final bedienung = Bedienung(tester);

      // Ausgangsstand: ein eigener Vorgang zur Mandantin aus dem Bestand —
      // vor dem Start der App, die ihre Vorgänge nur beim Start lädt.
      final mandantin = await DienstZugang.mandantMitNachname('Beispiel');
      final referenz = 'E2E-V ${lauf.zeitcode}';
      await DienstZugang.legeVorgangAn(
        referenz: referenz,
        kennzeichen: lauf.kennzeichen('VD'),
        unfallDatum: lauf.unfalldatum,
        mandant: mandantin,
      );

      await bedienung.starteApp();
      await bedienung.waehleReiter('Vorgänge');
      final kachel = find.byKey(ValueKey(referenz));
      await bedienung.tippe(
        find.descendant(of: kachel, matching: find.byTooltip('Vollmacht')),
      );

      // Der Dialog nennt den Drucker — im Testmodus die Attrappe.
      await bedienung.warteAuf(
        find.textContaining('Testmodus (kein Druck)'),
        frist: const Duration(seconds: 60),
        was: 'den Drucker der Attrappe im Vollmacht-Dialog',
      );
      // Bedienbar erst, wenn die Vorlage aus der Abteilung abgeleitet ist;
      // die erste Seitenvorschau rechnet Word (echt, ohne Außenwirkung).
      await bedienung.tippeAktiv(
        find.byKey(VollmachtDialogKnoepfe.druckenSchluessel),
        frist: const Duration(seconds: 90),
      );
      await bedienung.warteAuf(
        find.text('Am Vorgang als gedruckt vermerkt'),
        frist: const Duration(seconds: 60),
        was: 'das Ergebnis des Drucks',
      );
      await bedienung.tippe(find.text('Fertig'));
      await bedienung.warteAuf(
        find.descendant(
          of: kachel,
          matching: find.textContaining('Vollmacht gedruckt am'),
        ),
        was: 'den Druckvermerk an der Vorgangskachel',
      );

      // Die Druck-Attrappe hat genau eine Kopie abgelegt — eine .docx.
      final drucke = spuren.seitMitAktion(marke, 'druck');
      expect(drucke, hasLength(1));
      final kopie = spuren.datei(drucke.single);
      expect(kopie.path.toLowerCase(), endsWith('.docx'));
      expect(
        TestmodusSpuren.istZipArchiv(kopie),
        isTrue,
        reason: 'Die Druck-Kopie ist keine Word-Datei: ${kopie.path}',
      );

      // Der Vermerk steht im Bestand, nicht nur auf dem Schirm.
      final vorgang = await DienstZugang.vorgang(referenz);
      expect(vorgang['vollmachtGedrucktAm'], isNotNull);
    },
  );
}
