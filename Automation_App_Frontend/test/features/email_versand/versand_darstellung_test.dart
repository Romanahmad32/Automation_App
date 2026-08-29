import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/presentation/utils/outlook_griff_meldung.dart';
import 'package:automation_app/features/email_versand/presentation/utils/versand_darstellung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die beiden Sätze, mit denen die App über den Versand Auskunft gibt.
///
/// Beide tragen dieselbe fachlich heikle Unterscheidung (§4.8): Was die App
/// gesehen hat, darf sie behaupten — alles andere nicht. Ein Protokoll, das
/// eine Übergabe an Outlook als Versand ausgibt, wäre als Nachweis schlechter
/// als keines, und ein Griff, der wortlos nichts tut, schickt den Anwalt in
/// Outlook suchen.
void main() {
  VersandEintrag eintrag(VersandWeg weg, {bool imGesendetOrdner = false}) =>
      VersandEintrag(
        vorgangReferenz: '84/2026 C03_HG-E 1427',
        gesendetAm: DateTime(2026, 8, 25, 14, 12),
        weg: weg,
        imGesendetOrdner: imGesendetOrdner,
      );

  group('VersandDarstellung.ablage', () {
    test('beim Direktversand steht, wo die Mail liegt', () {
      final satz = VersandDarstellung.ablage(
        eintrag(VersandWeg.direktversand, imGesendetOrdner: true),
      );

      expect(satz, contains('Gesendet'));
      expect(satz, contains('Outlook'));
    });

    test('ohne Kopie im Gesendet-Ordner sagt sie das auch', () {
      // Sonst sucht der Anwalt dort umsonst und hält den Versand für
      // ausgeblieben.
      final satz = VersandDarstellung.ablage(eintrag(VersandWeg.direktversand));

      expect(satz, contains('nicht ablegen'));
    });

    test('eine Übergabe an Outlook behauptet keinen Versand', () {
      for (final weg in [VersandWeg.outlookEntwurf, VersandWeg.entwurfsdatei]) {
        final satz = VersandDarstellung.ablage(eintrag(weg));

        expect(satz, contains('weiß die App'), reason: '$weg');
        expect(satz, isNot(contains('Gesendet')), reason: '$weg');
      }
    });

    test('die Tat trennt Versand und Übergabe im Wortlaut', () {
      expect(VersandDarstellung.tat(VersandWeg.direktversand), 'Versendet');
      expect(
        VersandDarstellung.tat(VersandWeg.outlookEntwurf),
        isNot(contains('ersendet')),
      );
      expect(
        VersandDarstellung.tat(VersandWeg.entwurfsdatei),
        isNot(contains('ersendet')),
      );
    });

    test('nur der Direktversand gilt als Nachweis', () {
      expect(VersandWeg.direktversand.istNachweis, isTrue);
      expect(VersandWeg.outlookEntwurf.istNachweis, isFalse);
      expect(VersandWeg.entwurfsdatei.istNachweis, isFalse);
    });
  });

  group('OutlookGriffMeldung', () {
    test('schweigendes Outlook wird als solches gemeldet', () {
      const griff = OutlookAnhaenge(outlookErreicht: false);

      expect(
        OutlookGriffMeldung.fuer(griff, 0),
        contains('Outlook hat nicht geantwortet'),
      );
    });

    test('keine Nachricht offen ist etwas anderes als kein Anhang', () {
      const ohneNachricht = OutlookAnhaenge();
      const ohneAnhang = OutlookAnhaenge(
        betreff: 'AW: Unfall vom 12.03.',
        absender: 'gegner@example.de',
      );

      expect(
        OutlookGriffMeldung.fuer(ohneNachricht, 0),
        contains('keine Nachricht'),
      );
      expect(
        OutlookGriffMeldung.fuer(ohneAnhang, 0),
        contains('hängt keine Datei'),
      );
      // Aus welcher Mail gelesen wurde, entscheidet Outlook — der Anwalt soll
      // es wenigstens erfahren.
      expect(
        OutlookGriffMeldung.fuer(ohneAnhang, 0),
        contains('AW: Unfall vom 12.03.'),
      );
    });

    test('schon vorhandene Vorschläge werden nicht als Fehler gemeldet', () {
      const griff = OutlookAnhaenge(
        pfade: ['C:/Temp/Gutachten.pdf'],
        betreff: 'AW: Unfall vom 12.03.',
      );

      expect(
        OutlookGriffMeldung.fuer(griff, 0),
        contains('stehen bereits in der Auswahl'),
      );
    });

    test('neue Vorschläge sprechen für sich — keine Meldung', () {
      const griff = OutlookAnhaenge(
        pfade: ['C:/Temp/Gutachten.pdf'],
        betreff: 'AW: Unfall vom 12.03.',
      );

      expect(OutlookGriffMeldung.fuer(griff, 1), isNull);
    });

    test('der Vorspann steht vor dem Satz, nicht statt seiner', () {
      const griff = OutlookAnhaenge(outlookErreicht: false);

      expect(
        OutlookGriffMeldung.fuer(griff, 0, vorspann: 'Die Datei kam leer an.'),
        startsWith('Die Datei kam leer an. Outlook hat nicht geantwortet'),
      );
      // Ohne Satz gibt es auch nichts anzukündigen.
      expect(
        OutlookGriffMeldung.fuer(
          const OutlookAnhaenge(
            pfade: ['C:/Temp/Gutachten.pdf'],
            betreff: 'AW: Unfall',
          ),
          1,
          vorspann: 'Die Datei kam leer an.',
        ),
        isNull,
      );
    });
  });
}
