// Durchlauf 1 der E2E-Suite (#184): der Hauptweg eines Mandats — Vorgang
// starten, Zentralruf anfragen, Antwort übernehmen, Anspruchsschreiben
// erzeugen und ablegen, versenden. Start nur über scripts/e2e-suite.ps1: Die
// Schranke am Anfang bricht gegen jeden Dienst ohne Testmodus ab; Zentralruf
// und Versand laufen dann gegen die Attrappen des Dienstes.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helfer/bedienung.dart';
import 'helfer/dienst_zugang.dart';
import 'helfer/e2e_umgebung.dart';
import 'helfer/eml_nachricht.dart';
import 'helfer/hauptweg_schritte.dart';
import 'helfer/lauf_kennung.dart';
import 'helfer/testmodus_spuren.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Hauptweg: Vorgang, Zentralruf, Antwort, Schreiben, Ablage, Versand',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await E2eUmgebung.stelleTestmodusSicher();
      final spuren = TestmodusSpuren.ausUmgebung();
      final marke = spuren.stand();
      final lauf = LaufKennung.jetzt();
      final kennzeichen = lauf.kennzeichen('HW');
      final mandant = await DienstZugang.mandantMitNachname('Mustermann');
      final mandantName = '${mandant['vorname']} ${mandant['nachname']}';
      final schritte = HauptwegSchritte(Bedienung(tester));

      await schritte.bedienung.starteApp();
      await schritte.vorgangStarten(
        mandantId: mandant['id'] as int,
        mandantFilter: mandant['nachname'] as String,
        kennzeichenGegner: kennzeichen,
        unfalldatum: lauf.unfalldatum,
      );

      // Die Zentralruf-Attrappe hat genau eine Anfrage protokolliert — mit
      // der Referenz, unter der der Vorgang gespeichert ist.
      final anfragen = spuren.seitMitAktion(marke, 'zentralruf-anfrage');
      expect(anfragen, hasLength(1));
      final referenz = anfragen.single.referenz!;
      expect(referenz, endsWith('_$kennzeichen'));

      // Die Antwort des Zentralrufs baut der Dienst (echter Mailaufbau,
      // echter Parser); eingefügt wird ihr Text wie eine weitergeleitete Mail.
      final antwort = await DienstZugang.schreibe(
        'POST',
        '/api/Simulation/zentralruf-antwort',
        {
          'referenz': referenz,
          'kennzeichen': kennzeichen,
          'unfallDatum': lauf.unfalldatum,
        },
      ) as Map<String, dynamic>;
      final versicherer = antwort['data'] as Map<String, dynamic>;
      await schritte.antwortUebernehmen(antwort['rawText'] as String);

      await schritte.schreibenErstellen(
        referenz: referenz,
        vorlage: 'Testmodus Anspruchsschreiben',
      );
      await schritte.inAkteAblegen(mandantName);
      await schritte.versenden();

      // Bestand: Antwort übernommen, Schreiben in der Akte abgelegt.
      final vorgang = await DienstZugang.vorgang(referenz);
      expect(vorgang['status'], 'abgelegt');
      expect(
        (vorgang['antwort'] as Map<String, dynamic>?)?['versichererName'],
        versicherer['versichererName'],
      );
      final schreiben = File(vorgang['dokumentPfad'] as String);
      expect(schreiben.existsSync(), isTrue, reason: schreiben.path);
      final wordName = schreiben.path.split(Platform.pathSeparator).last;
      final pdfName = '${wordName.substring(0, wordName.lastIndexOf('.'))}.pdf';

      // Versand-Attrappe: genau eine Mail, an Versicherung und Mandant, mit
      // dem Schreiben als PDF — und die Kopie in „Gesendet".
      final versand = spuren.seitMitAktion(marke, 'versand');
      expect(versand, hasLength(1));
      final mail = EmlNachricht.lies(spuren.datei(versand.single));
      expect(
        [...mail.an, ...mail.kopie],
        containsAll([
          (versicherer['versichererEmail'] as String).toLowerCase(),
          (mandant['emailAdresse'] as String).toLowerCase(),
        ]),
      );
      expect(mail.anhaenge, [pdfName]);
      expect(spuren.seitMitAktion(marke, 'gesendet-ablage'), hasLength(1));
    },
  );
}
