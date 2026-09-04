import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/utils/signatur_html_aufbereitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outlooks Signatur-HTML fuer die Vorschau anzeigbar machen (§4.7).
///
/// Die Vorschau zeigte lange Outlooks Nur-Text-Uebersetzung und damit etwas
/// anderes, als beim Empfaenger ankommt. Jetzt wird die formatierte Fassung
/// gerendert — dafuer muessen ihre Bildverweise auf den Dienst zeigen, und was
/// fuer diese Mail abgewaehlt ist, darf nicht doch erscheinen.
void main() {
  const mitLogo =
      '<p><b>Kanzlei Ahmad</b></p>'
      '<img width=328 src="image001.png">'
      '<img src="werbung.gif" alt="Werbung">';

  test('macht aus dem Dateinamen die Adresse des Dienstes', () {
    final fertig = SignaturHtmlAufbereitung.fuerAnzeige(mitLogo);

    expect(fertig, contains('/api/EmailVersand/signaturen/bild'));
    expect(fertig, contains('dateiname=image001.png'));
    // Der blanke Dateiname taugt als Quelle nicht: Er zeigt auf nichts, was
    // die Oberflaeche laden koennte.
    expect(fertig, isNot(contains('src="image001.png"')));
  });

  test('ein abgewaehltes Bild verschwindet ganz', () {
    // Nicht nur seine Quelle: Ein img ohne src zeigt ein Platzhalterkreuz und
    // saehe nach einem Fehler aus statt nach einer Entscheidung.
    final fertig = SignaturHtmlAufbereitung.fuerAnzeige(
      mitLogo,
      weggelassen: const ['werbung.gif'],
    );

    expect(fertig, isNot(contains('werbung.gif')));
    expect(fertig, isNot(contains('alt="Werbung"')));
    expect(fertig, contains('dateiname=image001.png'));
  });

  test('laesst Verweise ins Netz stehen', () {
    // Sie zeigen auf einen Server, der sie ausliefert — durch die Ablage des
    // Dienstes zu leiten, ginge daneben.
    const html = '<img src="https://kanzlei.example.de/logo.png">';

    expect(SignaturHtmlAufbereitung.fuerAnzeige(html), html);
  });

  test('ohne HTML-Fassung bleibt nichts uebrig', () {
    expect(SignaturHtmlAufbereitung.fuerAnzeige('   '), isEmpty);
  });

  test('laesst den Text der Signatur unangetastet', () {
    final fertig = SignaturHtmlAufbereitung.fuerAnzeige(mitLogo);

    expect(fertig, contains('<b>Kanzlei Ahmad</b>'));
  });

  test('die Marke des Bildes steht in der Adresse', () {
    // Outlook nennt das erste Bild jeder Signatur image001.png. Ohne die Marke
    // ist die Adresse nach einem Signaturwechsel dieselbe — und Flutter, das
    // Bilder je Adresse aufhebt, zeigt weiter das alte Logo.
    final alt = SignaturHtmlAufbereitung.fuerAnzeige(
      mitLogo,
      bilder: const [
        SignaturBild(dateiname: 'image001.png', bytes: 4096, marke: 'a1b2c3'),
      ],
    );
    final neu = SignaturHtmlAufbereitung.fuerAnzeige(
      mitLogo,
      bilder: const [
        SignaturBild(dateiname: 'image001.png', bytes: 5120, marke: 'd4e5f6'),
      ],
    );

    expect(alt, contains('marke=a1b2c3'));
    expect(neu, contains('marke=d4e5f6'));
  });

  test('eine gelesene Signatur holt ihre Bilder aus Outlook', () {
    // Vor dem Speichern liegen sie noch nicht in der Ablage des Dienstes.
    // Ohne diesen Zusatz lieferte er von dort das gleichnamige Bild der
    // vorigen Signatur aus, und die Vorschau zeigte es als das neue.
    final fertig = SignaturHtmlAufbereitung.fuerAnzeige(
      mitLogo,
      ausOutlook: 'neu Kanzlei',
    );

    expect(fertig, contains('signatur=neu+Kanzlei'));
    // Die gespeicherte Signatur kommt weiterhin aus der Ablage.
    expect(
      SignaturHtmlAufbereitung.fuerAnzeige(mitLogo),
      isNot(contains('signatur=')),
    );
  });
}
