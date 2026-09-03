import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Mandant geht als JSON über die Leitung; die Feldnamen sind die einzige
/// Verbindung zum Backend-DTO (`docs/openapi.json`). Ein Tippfehler darin ist
/// zur Laufzeit ein leeres Feld, kein Übersetzungsfehler — deshalb hier
/// geprüft.
void main() {
  final erstellt = DateTime.utc(2026, 8, 25, 19, 16);

  group('persönliche Grußformel', () {
    test('fehlt sie im JSON, ist sie leer — kein Zusatzgruß', () {
      final mandant = Mandant.fromJson({
        'id': 7,
        'nachname': 'Bein',
        'erstelltAm': erstellt.toIso8601String(),
      });

      expect(mandant.persoenlicheGrussformel, isEmpty);
    });

    test('sie übersteht den Weg durch JSON hin und zurück', () {
      final mandant = Mandant(
        id: 7,
        anrede: Anrede.herr,
        nachname: 'Bein',
        persoenlicheGrussformel: 'Salamu aleikum',
        erstelltAm: erstellt,
      );

      final zurueck = Mandant.fromJson(mandant.toJson());

      expect(zurueck.persoenlicheGrussformel, 'Salamu aleikum');
      expect(zurueck, mandant, reason: 'sie gehört zur Gleichheit');
    });

    test('copyWith setzt sie und kann sie wieder leeren', () {
      final ohne = Mandant(id: 7, nachname: 'Bein', erstelltAm: erstellt);

      final mit = ohne.copyWith(persoenlicheGrussformel: 'Sat Sri Akal');
      expect(mit.persoenlicheGrussformel, 'Sat Sri Akal');
      expect(
        mit.copyWith(persoenlicheGrussformel: '').persoenlicheGrussformel,
        isEmpty,
      );
    });
  });
}
