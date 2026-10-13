import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_umgebung.dart';

/// Der direkte Draht der Suite zum Testmodus-Dienst — für das, was **nicht**
/// über die Oberfläche läuft: den Ausgangsstand eines Durchlaufs anlegen
/// (etwa einen Vorgang) und das Ergebnis nachprüfen.
///
/// Gelesen werden darf jederzeit; **geschrieben wird erst nach der Schranke**
/// ([E2eUmgebung.stelleTestmodusSicher]). Ein Schreibaufruf davor ist ein
/// Fehler im Durchlauf und bricht ab, statt womöglich den echten Bestand zu
/// treffen.
abstract final class DienstZugang {
  static const Duration frist = Duration(seconds: 60);

  /// `GET <pfad>` und die Antwort als JSON (Objekt oder Liste).
  static Future<Object?> hole(String pfad) => _sende('GET', pfad, null);

  /// `PUT`/`POST` mit JSON-Körper; nur nach bestandener Schranke.
  static Future<Object?> schreibe(String methode, String pfad, Object inhalt) {
    if (!E2eUmgebung.geprueft) {
      throw StateError(
        'Schreibzugriff auf $pfad vor der Testmodus-Prüfung — abgebrochen.',
      );
    }
    return _sende(methode, pfad, inhalt);
  }

  /// Alle Vorgänge des Testbestands (`GET /api/Vorgaenge`).
  static Future<List<Map<String, dynamic>>> vorgaenge() async =>
      _liste(await hole('/api/Vorgaenge'));

  /// Alle Mandanten des Testbestands (`GET /api/Mandanten`).
  static Future<List<Map<String, dynamic>>> mandanten() async =>
      _liste(await hole('/api/Mandanten'));

  /// Der Vorgang mit genau dieser [referenz], oder ein Testfehler.
  static Future<Map<String, dynamic>> vorgang(String referenz) async {
    for (final vorgang in await vorgaenge()) {
      if (vorgang['referenz'] == referenz) return vorgang;
    }
    fail('Kein Vorgang mit der Referenz „$referenz" im Testbestand.');
  }

  /// Legt einen Vorgang im Status „angefragt" zu [mandant] an — derselbe
  /// `PUT`, den `scripts/e2e-testdaten.ps1 -MitVorgang` schickt, mit allen
  /// Feldern des Vertrags (`VorgangDto`), die übrigen leer. Die Abteilung C03
  /// (Verkehrsrecht) trägt er wie jeder echte Vorgang: An ihr leitet die
  /// Vollmacht ihre Vorlage ab, solange der Sachgebietskatalog noch lädt.
  static Future<void> legeVorgangAn({
    required String referenz,
    required String kennzeichen,
    required String unfallDatum,
    required Map<String, dynamic> mandant,
  }) async {
    const leer = [
      'laufendeNummer',
      'jahr',
      'gegner',
      'geschaedigtenKennzeichen',
      'unfallort',
      'unfalluhrzeit',
      'polizeiVorgangsnummer',
      'antwort',
      'feldWerte',
      'schadensaufstellung',
      'entwurf',
      'schreibenNummer',
      'dokumentPfad',
      'aktenOrdner',
      'abgeschlossenAm',
    ];
    await schreibe('PUT', '/api/Vorgaenge', {
      'referenz': referenz,
      'angefragtAm': DateTime.now().toUtc().toIso8601String(),
      'status': 'angefragt',
      'rechtsgebiet': 'Verkehrsrecht',
      'abteilung': 'C03',
      'kennzeichen': kennzeichen,
      'mandantId': mandant['id'],
      'mandantName': '${mandant['vorname']} ${mandant['nachname']}',
      'unfallDatum': unfallDatum,
      for (final feld in leer) feld: null,
    });
  }

  /// Der eine Mandant mit diesem [nachname], oder ein Testfehler.
  static Future<Map<String, dynamic>> mandantMitNachname(
    String nachname,
  ) async {
    final treffer = [
      for (final mandant in await mandanten())
        if (mandant['nachname'] == nachname) mandant,
    ];
    if (treffer.length != 1) {
      fail('Mandant „$nachname": ${treffer.length} Treffer statt genau 1.');
    }
    return treffer.single;
  }

  static List<Map<String, dynamic>> _liste(Object? json) {
    if (json is! List) fail('Erwartet war eine Liste, kam: $json');
    return [for (final eintrag in json) eintrag as Map<String, dynamic>];
  }

  static Future<Object?> _sende(
    String methode,
    String pfad,
    Object? inhalt,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final anfrage = await client.openUrl(
        methode,
        Uri.parse('${BackendEndpoint.basisUrl}$pfad'),
      );
      if (inhalt != null) {
        anfrage.headers.contentType = ContentType.json;
        anfrage.add(utf8.encode(jsonEncode(inhalt)));
      }
      final antwort = await anfrage.close().timeout(frist);
      final text = await antwort.transform(utf8.decoder).join();
      if (antwort.statusCode >= 300) {
        fail('$methode $pfad: ${antwort.statusCode} $text');
      }
      return text.trim().isEmpty ? null : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }
}
