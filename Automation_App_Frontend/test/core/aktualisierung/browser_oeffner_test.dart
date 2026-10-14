import 'dart:io';

import 'package:automation_app/core/aktualisierung/presentation/browser_oeffner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';

/// „Lieber selbst herunterladen“ öffnet eine Adresse aus einer API-Antwort
/// (#196). Früher über `cmd /c start`, wo ein `&` oder `|` darin zum Befehl
/// wurde; jetzt ohne Shell, und nur `https://github.com/…`. Gestartet wird
/// hier nichts — die Naht schreibt mit.
void main() {
  late List<List<String>> gestartet;

  setUp(() {
    gestartet = [];
    BrowserOeffner.starte = (programm, argumente) async =>
        gestartet.add([programm, ...argumente]);
  });
  tearDown(BrowserOeffner.zuruecksetzen);

  test('öffnet die Setup-Datei bei GitHub über rundll32, ohne cmd', () async {
    expect(await BrowserOeffner.oeffne(setupAdresse), isTrue);

    expect(gestartet, [
      ['rundll32', 'url.dll,FileProtocolHandler', setupAdresse],
    ]);
  });

  test('& und % bleiben Teil des einen Arguments', () async {
    const adresse = 'https://github.com/a/b/releases?x=1&y=%41';

    expect(await BrowserOeffner.oeffne(adresse), isTrue);

    expect(gestartet.single, hasLength(3));
    expect(gestartet.single.last, adresse);
  });

  const abgelehnt = {
    'http statt https':
        'http://github.com/Romanahmad32/Automation_App/releases/download/'
        'v1.4.0/Automation_App_Setup_1.4.0.exe',
    'fremder Host': 'https://example.invalid/Automation_App_Setup_1.4.0.exe',
    'github.com nur als Vorsilbe':
        'https://github.com.example.invalid/Automation_App_Setup_1.4.0.exe',
    'anderer GitHub-Host':
        'https://objects.githubusercontent.com/Automation_App_Setup_1.4.0.exe',
    'mit Anmeldedaten': 'https://anwalt@github.com/x.exe',
    'fremder Port': 'https://github.com:8443/x.exe',
    'Anführungszeichen und Leerzeichen': 'https://github.com/x.exe" & calc',
    'Pipe': 'https://github.com/x.exe|calc',
    'Caret': 'https://github.com/x.exe^&calc',
    'Datei statt Adresse': 'file:///C:/Windows/System32/calc.exe',
    'ohne Schema': 'github.com/x.exe',
    'leer': '',
  };

  for (final MapEntry(key: fall, value: adresse) in abgelehnt.entries) {
    test('öffnet nichts: $fall', () async {
      expect(BrowserOeffner.istErlaubt(adresse), isFalse);
      expect(await BrowserOeffner.oeffne(adresse), isFalse);
      expect(gestartet, isEmpty);
    });
  }

  test('scheitert der Start, ist nichts geöffnet', () async {
    BrowserOeffner.starte = (programm, argumente) async =>
        throw const ProcessException('rundll32', [], 'nicht gefunden');

    expect(await BrowserOeffner.oeffne(setupAdresse), isFalse);
  });

  test('zurücksetzen stellt den echten Weg ohne Shell wieder her', () {
    BrowserOeffner.zuruecksetzen();

    expect(BrowserOeffner.starte, BrowserOeffner.ohneShell);
  });
}
