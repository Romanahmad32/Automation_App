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
}
