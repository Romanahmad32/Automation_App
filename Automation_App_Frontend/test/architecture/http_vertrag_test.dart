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

  // Feldnamen: je Dart-Datei die Backend-DTOs, deren camelCase-Eigenschaften
  // sie von Hand fuehrt — meist eines; ein zweites, wo das Anlegen oder
  // Aendern ueber ein eigenes Create-/Update-DTO laeuft.
  //
  // Der Test unten haelt die Liste vollstaendig: jede Datei unter lib/ mit
  // json['…']-Zugriffen muss hier oder in [ohneDto] stehen. Die Liste einmal
  // zu fuellen repariert den Bestand; sie vollstaendig zu halten repariert
  // ihn dauerhaft.
  const gespiegelteDtos = <String, List<String>>{
    'lib/features/backup/domain/entities/letzte_sicherung.dart': [
      'LetzteSicherungDto',
    ],
    'lib/features/backup/domain/entities/uebergabe_angebot.dart': [
      'UebergabeAngebotDto',
    ],
    'lib/features/backup/domain/entities/uebergabe_stand.dart': [
      'UebergabeStandDto',
    ],
    'lib/features/email_versand/domain/entities/email_entwurf_ergebnis.dart': [
      'EntwurfErgebnisDto',
    ],
    'lib/features/email_versand/domain/entities/email_versand_bereitschaft.dart':
        ['EmailVersandBereitschaftDto'],
    'lib/features/email_versand/domain/entities/email_versand_ergebnis.dart': [
      'EmailVersandErgebnisDto',
    ],
    'lib/features/email_versand/domain/entities/outlook_anhaenge.dart': [
      'OutlookAnhaengeDto',
    ],
    'lib/features/email_versand/domain/entities/outlook_signatur.dart': [
      'OutlookSignaturDto',
    ],
    'lib/features/email_versand/domain/entities/outlook_stand.dart': [
      'OutlookStandDto',
    ],
    'lib/features/email_versand/domain/entities/signatur_bild.dart': [
      'SignaturBildDto',
    ],
    'lib/features/email_versand/domain/entities/signatur_stand.dart': [
      'SignaturStandDto',
    ],
    'lib/features/email_versand/domain/entities/versand_eintrag.dart': [
      'VersandEintragDto',
    ],
    'lib/features/form_template_setup/domain/entities/form_template.dart': [
      'FormTemplateDto',
      'CreateFormTemplateDto',
    ],
    'lib/features/mailbox/domain/entities/mailbox_config.dart': [
      'MailboxConfigDto',
      'MailboxConfigUpdateDto',
    ],
    'lib/features/mailbox/domain/entities/mailbox_status.dart': [
      'MailboxStatusDto',
    ],
    'lib/features/mailbox/domain/entities/received_reply.dart': [
      'ReceivedReplyDto',
    ],
    'lib/features/mandanten/domain/entities/import_bericht.dart': [
      'ImportBerichtDto',
      'ImportEintragDto',
    ],
    'lib/features/mandanten/domain/entities/mandant.dart': [
      'MandantDto',
      'CreateMandantDto',
    ],
    'lib/features/mandanten/domain/entities/mandanten_import_datei.dart': [
      'MandantenImportDto',
      'ImportMandantDto',
    ],
    'lib/features/mandanten/domain/entities/mandanten_seite.dart': [
      'MandantenSeiteDto',
    ],
    'lib/features/mandanten/domain/entities/ordner_status.dart': [
      'OrdnerStatusDto',
    ],
    'lib/features/settings/domain/entities/kanzlei_settings.dart': [
      'KanzleiSettingsDto',
    ],
    'lib/features/versicherer/domain/entities/versicherer.dart': [
      'VersichererDto',
    ],
    'lib/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart': [
      'RegisterSpiegelDto',
    ],
    'lib/features/vorgaenge/domain/entities/vorgang_json.dart': ['VorgangDto'],
    'lib/features/word_automation/domain/entities/standard_schadenspositionen.dart':
        ['StandardSchadenspositionDto'],
    'lib/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart':
        ['ArbeitsordnerAufgeraeumtDto', 'ArbeitsordnerDto'],
    'lib/features/word_automation/domain/entities/damage_listing.dart': [
      'DamageListingDto',
      'DamageItemDto',
    ],
    'lib/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart':
        ['ZentralrufReplyData'],
  };

  // Dateien mit json['…']-Zugriffen, die bewusst kein Backend-DTO spiegeln —
  // mit dem Grund, damit die naechste Aenderung ihn nachpruefen kann statt
  // ihn zu glauben.
  const ohneDto = <String, String>{
    'lib/core/backend/backend_health_probe.dart':
        'liest GET /health — die Bereitschaftsabfrage vor dem DI-Aufbau, '
        'bewusst kein Teil des OpenAPI-Vertrags',
    'lib/core/theme/domain/theme_preferences.dart':
        'geraetelokale Darstellungs-Einstellung, geht nie ueber HTTP',
    'lib/features/form_template_setup/domain/entities/field_data.dart':
        'Inhalt der opaken fields-Spalte von FormTemplateDto — das Schema '
        'lebt nur in Dart (FALLSTRICKE.md des Features)',
    'lib/features/vorgaenge/domain/entities/vorgang_entwurf.dart':
        'Inhalt des opaken entwurf-Felds von VorgangDto — das Backend reicht '
        'den angefangenen Ausfuellstand durch, ohne ihn zu kennen, das Schema '
        'lebt nur in Dart (FALLSTRICKE.md von word_automation)',
  };

  test('jede Datei mit json-Zugriffen ist ihrem Backend-DTO zugeordnet', () {
    final zugeordnet = {...gespiegelteDtos.keys, ...ohneDto.keys};
    final mitJsonZugriff = <String>{
      for (final datei in dartQuelldateien('lib'))
        if (datei.readAsStringSync().contains("json['")) relPfad(datei),
    };

    final unzugeordnet = mitJsonZugriff.difference(zugeordnet).toList()..sort();
    expect(
      unzugeordnet,
      isEmpty,
      reason:
          'Diese Dateien fuehren Feldnamen von Hand, stehen aber in keiner '
          'der beiden Listen dieses Tests. In gespiegelteDtos das DTO aus '
          'docs/openapi.json eintragen — oder, wenn die Datei wirklich kein '
          'Backend-DTO spiegelt, mit Begruendung in ohneDto:\n  '
          '${unzugeordnet.join('\n  ')}',
    );

    final veraltet = zugeordnet.difference(mitJsonZugriff).toList()..sort();
    expect(
      veraltet,
      isEmpty,
      reason:
          'Diese Eintraege zeigen auf Dateien ohne json-Zugriffe mehr '
          '(geloescht, verschoben oder umgebaut) — Eintrag entfernen oder '
          'Pfad nachziehen:\n  ${veraltet.join('\n  ')}',
    );
  });

  final schemata =
      (vertrag['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;

  for (final eintrag in gespiegelteDtos.entries) {
    test('${eintrag.key.split('/').last} benutzt nur Felder aus '
        '${eintrag.value.join(' und ')}', () {
      final erlaubt = <String>{};
      for (final dto in eintrag.value) {
        final schema = schemata[dto] as Map<String, dynamic>?;
        expect(
          schema,
          isNotNull,
          reason:
              'Das Schema $dto steht nicht in docs/openapi.json — '
              'wurde das DTO umbenannt oder entfernt?',
        );
        erlaubt.addAll((schema!['properties'] as Map<String, dynamic>).keys);
      }

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
            'Diese Feldnamen benutzt ${eintrag.key}, die Backend-DTOs '
            '${eintrag.value.join(' und ')} kennen sie aber nicht. Ein '
            'solcher Name faellt sonst nirgends auf: die Anwendung '
            'uebersetzt, alle Tests bleiben gruen, und das Feld ist zur '
            'Laufzeit still null.\n  ${unbekannt.join('\n  ')}',
      );
    });
  }
}
