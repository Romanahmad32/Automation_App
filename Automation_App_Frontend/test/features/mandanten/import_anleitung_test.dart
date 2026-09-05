import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Auftragstext ist die eigentliche Schnittstelle zum Erzeuger der
/// Importdatei: Er wird kopiert, in ein anderes Programm gegeben und dort
/// befolgt: was hier fehlt, fehlt in der Datei. Geprüft wird deshalb nicht der
/// Wortlaut, sondern dass die vier Aussagen darin stehen, ohne die ein
/// Arbeitspaket schadet statt nützt.
void main() {
  test('beide Aufträge beschreiben denselben Dateiaufbau', () {
    expect(ImportAnleitung.text, contains(ImportAnleitung.dateiaufbau));
    expect(ImportAnleitung.paketText, contains(ImportAnleitung.dateiaufbau));
    expect(
      ImportAnleitung.dateiaufbau,
      contains('"version": 1'),
      reason: 'die Antwort bleibt die Importdatei in Fassung 1',
    );
  });

  test('der Paketauftrag hält die Ordnerliste geschlossen', () {
    expect(ImportAnleitung.paketText, contains('GENAU die Ordner'));
    expect(ImportAnleitung.paketText, contains('keine anderen'));
  });

  // Der Ordnername ist das einzige Band zwischen Paket und App: Zuordnung und
  // Vermerk hängen daran, nicht an einem Pfad und nicht an einer Nummer.
  test('der Paketauftrag verlangt den Ordnernamen zeichengenau', () {
    expect(ImportAnleitung.paketText, contains('ZEICHENGENAU'));
    expect(ImportAnleitung.paketText, contains('Nicht abtippen'));
    expect(ImportAnleitung.paketText, contains('nicht kürzen'));
  });

  test('der Paketauftrag nennt die bekannten Mandanten und das Nachlesen', () {
    expect(ImportAnleitung.paketText, contains('"bekannteMandanten"'));
    expect(
      ImportAnleitung.paketText,
      contains('statt einen neuen anzulegen'),
      reason: 'genau so entsteht sonst die Dublette, die das Paket verhindert',
    );
    expect(ImportAnleitung.paketText, contains('Lies nur DORT in die '));
  });

  // Der Auftrag ohne Paket bleibt, wie er war — auf einem Rechner ohne
  // Arbeitspaket ist er weiterhin der ganze Weg.
  test('der Auftrag ohne Paket nennt den Stammordner', () {
    expect(ImportAnleitung.text, contains('Stammordner: <Pfad zum'));
    expect(ImportAnleitung.text, isNot(contains('arbeitspaket-')));
  });
}
