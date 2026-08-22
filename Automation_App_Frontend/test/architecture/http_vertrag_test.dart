import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Prueft die Dart-Seite des HTTP-Vertrags gegen `docs/openapi.json`.
///
/// Frontend und Backend sind ueber nichts als Zeichenketten verbunden: die
/// Endpunktpfade in den Datasources und die camelCase-Feldnamen der DTOs.
/// Diese Kopplung ist die einzige Fehlerquelle, die die gesamte gruene
/// Pruefkette passiert — `dotnet build`, `dotnet test`, `flutter analyze` und
/// `flutter test` merken nichts davon, und das Feld ist erst zur Laufzeit
/// still null.
///
/// Die Gegenseite ist `AutomationService.Tests/Integration/OpenApiVertragTests`:
/// dort wird der Vertrag aus dem laufenden Dienst exportiert. Hier wird
/// geprueft, dass Dart nur benutzt, was darin steht.
void main() {
  final vertragsDatei = File('../docs/openapi.json');

  // Ein Vertragstest, der still gruen wird, weil er die Vergleichsdatei nicht
  // findet, meldet Erfolg fuer eine Pruefung, die nie gelaufen ist.
  if (!vertragsDatei.existsSync()) {
    test('docs/openapi.json ist vorhanden', () {
      fail(
        'docs/openapi.json fehlt. Sie entsteht beim Backend-Testlauf '
        '(dotnet test AutomationService.Tests). Ohne sie ist der HTTP-Vertrag '
        'nicht pruefbar.',
      );
    });
    return;
  }

  final vertrag =
      jsonDecode(vertragsDatei.readAsStringSync()) as Map<String, dynamic>;

  // Pfadschablonen vergleichbar machen: Platzhalter vereinheitlichen und
  // Gross-/Kleinschreibung ignorieren. Das ASP.NET-Routing ist
  // case-insensitiv — die Dart-Seite schreibt teils `/api/mailbox/...`, der
  // Vertrag `/api/Mailbox/...`, und beides trifft denselben Endpunkt.
  String vereinheitlicht(String pfad) => pfad
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '{}') // ${ausdruck}
      .replaceAll(RegExp(r'\$\w+'), '{}') //       $bezeichner
      .replaceAll(RegExp(r'\{[^}]*\}'), '{}') //   {id} aus OpenAPI
      .toLowerCase();

  final vertragsPfade = {
    for (final pfad in (vertrag['paths'] as Map<String, dynamic>).keys)
      vereinheitlicht(pfad),
  };

  test('jeder im Dart-Code benutzte Endpunkt steht im Vertrag', () {
    final pfadLiteral = RegExp(r"""['"](/api/[^'"]*)['"]""");
    final unbekannt = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      for (final treffer in pfadLiteral.allMatches(datei.readAsStringSync())) {
        final roh = treffer.group(1)!;
        if (!vertragsPfade.contains(vereinheitlicht(roh))) {
          unbekannt.add('${relPfad(datei)}: $roh');
        }
      }
    }
    unbekannt.sort();

    expect(
      unbekannt,
      isEmpty,
      reason:
          'Diese Pfade kommen im Dart-Code vor, aber nicht in docs/openapi.json. '
          'Entweder ist der Pfad falsch geschrieben, oder der Endpunkt wurde im '
          'Backend umbenannt/entfernt, ohne dass die Dart-Seite nachgezogen '
          'wurde:\n  ${unbekannt.join('\n  ')}',
    );
  });

  // Feldnamen: je Dart-Datei das DTO, dessen camelCase-Eigenschaften sie
  // spiegelt. Weitere Paare gehoeren hier hinein, sobald eine Datei die
  // Feldnamen eines DTOs von Hand fuehrt.
  const gespiegelteDtos = {
    'lib/features/vorgaenge/domain/entities/vorgang_json.dart': 'VorgangDto',
  };

  final schemata =
      (vertrag['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;

  for (final eintrag in gespiegelteDtos.entries) {
    test('${eintrag.key.split('/').last} benutzt nur Felder aus '
        '${eintrag.value}', () {
      final schema = schemata[eintrag.value] as Map<String, dynamic>?;
      expect(
        schema,
        isNotNull,
        reason:
            'Das Schema ${eintrag.value} steht nicht in docs/openapi.json — '
            'wurde das DTO umbenannt oder entfernt?',
      );

      final erlaubt = (schema!['properties'] as Map<String, dynamic>).keys
          .toSet();

      final quelle = File(eintrag.key).readAsStringSync();
      final gelesen = RegExp(
        r"""json\['(\w+)'\]""",
      ).allMatches(quelle).map((t) => t.group(1)!);
      final geschrieben = RegExp(
        r"""^\s*'(\w+)':""",
        multiLine: true,
      ).allMatches(quelle).map((t) => t.group(1)!);

      final unbekannt = {
        ...gelesen,
        ...geschrieben,
      }.difference(erlaubt).toList()..sort();

      expect(
        unbekannt,
        isEmpty,
        reason:
            'Diese Feldnamen benutzt ${eintrag.key}, das Backend-DTO '
            '${eintrag.value} kennt sie aber nicht. Ein solcher Name faellt '
            'sonst nirgends auf: die Anwendung uebersetzt, alle Tests bleiben '
            'gruen, und das Feld ist zur Laufzeit still null.\n  '
            '${unbekannt.join('\n  ')}',
      );
    });
  }
}
