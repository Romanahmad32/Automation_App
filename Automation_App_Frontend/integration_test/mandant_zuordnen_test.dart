// Durchlauf 3 der E2E-Suite (#184): Mandant anlegen und einem Vorgang
// zuordnen. Start nur über scripts/e2e-suite.ps1 — die Schranke am Anfang
// bricht gegen jeden Dienst ohne Testmodus ab.
import 'package:automation_app/core/general_widgets/form/feld_schluessel.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_overview.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_card.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
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
    'Mandant im Register anlegen und beim Vorgang starten zuordnen',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await E2eUmgebung.stelleTestmodusSicher();
      final spuren = TestmodusSpuren.ausUmgebung();
      final marke = spuren.stand();
      final lauf = LaufKennung.jetzt();
      final nachname = lauf.nachname('Zuordnung');
      final kennzeichen = lauf.kennzeichen('MZ');
      final bedienung = Bedienung(tester);
      Finder feld(String name) => find.byKey(FeldSchluessel.fuer(name)!);

      await bedienung.starteApp();

      // Reiter Mandanten: neuen Mandanten anlegen.
      await bedienung.waehleReiter('Mandanten');
      await bedienung.tippe(find.text('Neuer Mandant'));
      await bedienung.warteAuf(find.text('Stammdaten des Mandanten'));
      await bedienung.tippe(
        find.descendant(
          of: find.byType(SegmentedButton<Anrede>),
          matching: find.text('Herr'),
        ),
      );
      await bedienung.gebeEin(feld('vorname'), 'Erik');
      await bedienung.gebeEin(feld('nachname'), nachname);
      await bedienung.gebeEin(feld('emailAdresse'), lauf.email('Zuordnung'));
      await bedienung.tippeAktiv(find.text('Speichern'));
      await bedienung.warteBisWeg(find.text('Stammdaten des Mandanten'));

      final mandant = await DienstZugang.mandantMitNachname(nachname);
      final mandantId = mandant['id'] as int;
      await bedienung.gebeEin(
        find.byKey(MandantenOverview.sucheSchluessel),
        nachname,
      );
      await bedienung.warteAuf(
        find.byKey(MandantCard.schluessel(mandantId)),
        was: 'die Karte des neuen Mandanten',
      );

      // Reiter Vorgang starten: den Mandanten aus dem Register übernehmen.
      await bedienung.waehleReiter('Vorgang starten');
      await bedienung.waehleAus(
        find.byKey(MandantSection.auswahlSchluessel),
        find.byKey(MandantSection.eintragSchluessel(mandantId)),
        filter: nachname,
      );
      expect(bedienung.textIn(feld('mandantNachname')), nachname);
      await bedienung.gebeEin(feld('kennzeichenGegner'), kennzeichen);
      await bedienung.gebeEin(feld('schadentag'), lauf.unfalldatum);
      await bedienung.tippeAktiv(find.text('Vorgang speichern'));
      await bedienung.warteAuf(
        find.textContaining('gespeichert. Direkt weiterarbeiten?'),
        was: 'die Bestätigung des gespeicherten Vorgangs',
      );

      // Ergebnis im Bestand: genau ein neuer Vorgang hängt am Mandanten.
      final amMandanten = [
        for (final vorgang in await DienstZugang.vorgaenge())
          if (vorgang['mandantId'] == mandantId) vorgang,
      ];
      expect(amMandanten, hasLength(1));
      final vorgang = amMandanten.single;
      expect(vorgang['referenz'] as String, endsWith('_$kennzeichen'));
      expect(vorgang['mandantName'] as String, contains(nachname));
      expect(vorgang['unfallDatum'], lauf.unfalldatum);
      // „Vorgang speichern" fragt den Zentralruf nicht an.
      expect(spuren.seitMitAktion(marke, 'zentralruf-anfrage'), isEmpty);
    },
  );
}
