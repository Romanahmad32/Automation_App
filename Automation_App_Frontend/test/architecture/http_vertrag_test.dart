import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';
import 'dto_zuordnung.dart';

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

  final schemata =
      (vertrag['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;
  final zuordnung = DtoZuordnung(schemata.keys.toSet());

  // Alle Dateien, die Feldnamen von Hand fuehren, samt ihrer DTOs. Einmal
  // gelesen — jeder der Tests unten braucht dieselbe Liste.
  late final dateien = [
    for (final datei in dartQuelldateien('lib'))
      if (datei.readAsStringSync().contains("json['"))
        (
          pfad: relPfad(datei),
          quelle: datei.readAsStringSync(),
          dtos:
              abweichendeDtos[relPfad(datei)] ??
              zuordnung.dtosFuer(datei.readAsStringSync()),
        ),
  ];

  test('jede Datei mit json-Zugriffen ist ihrem Backend-DTO zugeordnet', () {
    final unzugeordnet = [
      for (final datei in dateien)
        if (datei.dtos.isEmpty && !ohneDto.containsKey(datei.pfad)) datei.pfad,
    ]..sort();

    expect(
      unzugeordnet,
      isEmpty,
      reason:
          'Zu diesen Dateien findet sich kein Backend-DTO. Der Test leitet es '
          'aus den Klassennamen ab (siehe dto_zuordnung.dart): zur Klasse '
          '<Sache> gehoert das Schema <Sache>Dto. Heisst das DTO anders, '
          'gehoert die Datei mit Begruendung in abweichendeDtos — spiegelt sie '
          'gar kein DTO, in ohneDto:\n  ${unzugeordnet.join('\n  ')}',
    );

    final mitJsonZugriff = {for (final datei in dateien) datei.pfad};
    final veraltet = {
      ...abweichendeDtos.keys,
      ...ohneDto.keys,
    }.difference(mitJsonZugriff).toList()..sort();

    expect(
      veraltet,
      isEmpty,
      reason:
          'Diese Eintraege zeigen auf Dateien ohne json-Zugriffe mehr '
          '(geloescht, verschoben oder umgebaut) — Eintrag entfernen oder '
          'Pfad nachziehen:\n  ${veraltet.join('\n  ')}',
    );
  });

  test('die Handliste nennt nur Schemata, die es im Vertrag gibt', () {
    final unbekannt = [
      for (final eintrag in abweichendeDtos.entries)
        for (final dto in eintrag.value)
          if (!schemata.containsKey(dto)) '${eintrag.key} -> $dto',
    ]..sort();

    expect(
      unbekannt,
      isEmpty,
      reason:
          'Diese Schemata stehen nicht in docs/openapi.json — umbenannt oder '
          'entfernt? Ein Eintrag, der ins Leere zeigt, nimmt der Datei ihre '
          'Pruefung, ohne dass etwas rot wird:\n  ${unbekannt.join('\n  ')}',
    );
  });

  test('jede Datei benutzt nur Feldnamen aus ihren Backend-DTOs', () {
    final gelesen = RegExp(r"""json\['(\w+)'\]""");
    final geschrieben = RegExp(r"""^\s*'(\w+)':""", multiLine: true);
    final verstoesse = <String>[];

    for (final datei in dateien) {
      if (datei.dtos.isEmpty) continue; // meldet der Test darueber
      final erlaubt = <String>{
        for (final dto in datei.dtos)
          ...((schemata[dto] as Map<String, dynamic>?)?['properties']
                      as Map<String, dynamic>? ??
                  const {})
              .keys,
      };

      final benutzt = {
        ...gelesen.allMatches(datei.quelle).map((t) => t.group(1)!),
        ...geschrieben.allMatches(datei.quelle).map((t) => t.group(1)!),
      };
      final unbekannt = benutzt.difference(erlaubt).toList()..sort();
      if (unbekannt.isNotEmpty) {
        verstoesse.add(
          '${datei.pfad} (${datei.dtos.join(', ')}): ${unbekannt.join(', ')}',
        );
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Feldnamen kennen die zugeordneten Backend-DTOs nicht. Ein '
          'solcher Name faellt sonst nirgends auf: die Anwendung uebersetzt, '
          'alle Tests bleiben gruen, und das Feld ist zur Laufzeit still '
          'null.\n  ${verstoesse.join('\n  ')}',
    );
  });
}
