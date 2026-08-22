import 'package:automation_app/core/aktualisierung/aktualisierungs_pruefer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ausschnitt der GitHub-Antwort, auf die es ankommt.
String antwort({required String tag}) =>
    '{"tag_name":"$tag",'
    '"html_url":"https://github.com/x/y/releases/tag/$tag",'
    '"name":"Automation App"}';

void main() {
  group('AktualisierungsPruefer.auswerten', () {
    test('meldet eine neuere Version samt Release-Seite', () {
      final neu = AktualisierungsPruefer.auswerten(
        antwort(tag: 'v1.1.0'),
        '1.0.0',
      );

      expect(neu, isNotNull);
      // Ohne führendes v: die Nummer landet unverändert vor dem Anwalt.
      expect(neu!.nummer, '1.1.0');
      expect(neu.seite, endsWith('/releases/tag/v1.1.0'));
    });

    test('schweigt bei gleicher und bei älterer Version', () {
      expect(
        AktualisierungsPruefer.auswerten(antwort(tag: 'v1.0.0'), '1.0.0'),
        isNull,
      );
      expect(
        AktualisierungsPruefer.auswerten(antwort(tag: 'v0.9.0'), '1.0.0'),
        isNull,
      );
    });

    test('fällt auf die Release-Übersicht zurück, wenn die URL fehlt', () {
      final neu = AktualisierungsPruefer.auswerten(
        '{"tag_name":"v1.1.0"}',
        '1.0.0',
      );

      expect(neu?.seite, AktualisierungsPruefer.releaseSeite);
    });

    test('verträgt Antworten, die keine sind', () {
      // Ein Fehlerobjekt, eine Fehlerseite, ein abgeschnittener Körper: nichts
      // davon darf die Anwendung stören — der Hinweis bleibt einfach aus.
      expect(AktualisierungsPruefer.auswerten('', '1.0.0'), isNull);
      expect(AktualisierungsPruefer.auswerten('<html>', '1.0.0'), isNull);
      expect(AktualisierungsPruefer.auswerten('[]', '1.0.0'), isNull);
      expect(
        AktualisierungsPruefer.auswerten('{"message":"Not Found"}', '1.0.0'),
        isNull,
      );
      expect(
        AktualisierungsPruefer.auswerten('{"tag_name":7}', '1.0.0'),
        isNull,
      );
    });
  });
}
