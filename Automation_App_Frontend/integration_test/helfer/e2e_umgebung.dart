import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Umgebung eines E2E-Laufs (#184) und die **Schranke davor**.
///
/// Die Suite tippt „Senden", „Drucken" und „Zentralruf-Formular ausfüllen" an
/// — gegen den echten Dienst der Kanzlei wäre das ein Versand an echte
/// Empfänger. Gefahrlos ist das nur, weil der Dienst im Testmodus läuft
/// (#168): eigener Datenordner, Attrappen statt Zentralruf, SMTP und Drucker.
/// Genau das stellt [stelleTestmodusSicher] fest, **bevor** die App startet
/// und bevor irgendetwas geschrieben wird. Fehlt eine Bedingung, scheitert
/// der Durchlauf sofort.
///
/// Gesetzt wird alles von `scripts/e2e-suite.ps1` per `--dart-define`.
abstract final class E2eUmgebung {
  /// Name des Dart-Defines mit dem Ordner `<Datenordner>\Testmodus` — dort
  /// liegen `protokoll.jsonl` und die Spuren der Attrappen.
  static const String testmodusOrdnerDefine = 'AUTOMATION_E2E_TESTMODUS_ORDNER';

  static const String testmodusOrdner = String.fromEnvironment(
    testmodusOrdnerDefine,
  );

  /// Der Port der installierten App. Ein Lauf dagegen ist nie gewollt.
  static const int portDerInstallation = 5143;

  static bool _geprueft = false;

  /// Ob [stelleTestmodusSicher] in diesem Prozess bestanden hat. Jeder
  /// schreibende Aufruf an den Dienst fragt das ab (`DienstZugang`).
  static bool get geprueft => _geprueft;

  /// Die Schranke: Testmodus-Define gesetzt, Port nicht der der Installation,
  /// Testmodus-Ordner angegeben, und `/health` meldet ausdrücklich
  /// `testmodus: true`. Schlägt eine Bedingung fehl, endet der Test hier.
  static Future<void> stelleTestmodusSicher() async {
    if (!BackendEndpoint.testmodusErwartet) {
      fail(
        'AUTOMATION_TESTMODUS=true fehlt. Die Suite nur über '
        'scripts/e2e-suite.ps1 starten.',
      );
    }
    if (BackendEndpoint.port == portDerInstallation) {
      fail(
        'Port $portDerInstallation gehört der installierten App — die Suite '
        'läuft nur gegen den Testmodus-Dienst (AUTOMATION_BACKEND_PORT).',
      );
    }
    if (testmodusOrdner.isEmpty || !Directory(testmodusOrdner).isAbsolute) {
      fail(
        '$testmodusOrdnerDefine fehlt oder ist kein absoluter Pfad. Die Suite '
        'nur über scripts/e2e-suite.ps1 starten.',
      );
    }
    final gesundheit = await _gesundheit();
    if (gesundheit['testmodus'] != true) {
      fail(
        'Der Dienst unter ${BackendEndpoint.adresse} meldet keinen Testmodus '
        '(/health: $gesundheit). Abgebrochen, bevor etwas angetippt wurde.',
      );
    }
    _geprueft = true;
  }

  /// `GET /health` — bewusst ohne `DienstZugang`, damit die Schranke selbst
  /// an nichts hängt, das sie erst freigeben soll.
  static Future<Map<String, dynamic>> _gesundheit() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final anfrage = await client.getUrl(Uri.parse(BackendEndpoint.healthUrl));
      final antwort = await anfrage.close().timeout(
        const Duration(seconds: 10),
      );
      final text = await antwort.transform(utf8.decoder).join();
      if (antwort.statusCode != HttpStatus.ok) {
        fail('/health antwortet mit ${antwort.statusCode}: $text');
      }
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) fail('/health ist kein Objekt: $text');
      return json;
    } on FormatException catch (fehler) {
      fail(
        'Unter ${BackendEndpoint.adresse} antwortet etwas, das kein Dienst '
        'dieser App ist (/health ist kein JSON: $fehler).',
      );
    } on SocketException catch (fehler) {
      fail(
        'Kein Dienst unter ${BackendEndpoint.adresse} ($fehler). Die Suite '
        'nur über scripts/e2e-suite.ps1 starten.',
      );
    } on TimeoutException catch (fehler) {
      fail(
        'Kein Dienst unter ${BackendEndpoint.adresse} ($fehler). Die Suite '
        'nur über scripts/e2e-suite.ps1 starten.',
      );
    } on HttpException catch (fehler) {
      // Nicht `on Exception`: TestFailure aus fail() oben ist selbst eine.
      fail(
        'Kein Dienst unter ${BackendEndpoint.adresse} ($fehler). Die Suite '
        'nur über scripts/e2e-suite.ps1 starten.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
