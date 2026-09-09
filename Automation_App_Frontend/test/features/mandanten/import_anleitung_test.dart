import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Auftragstext ist die eigentliche Schnittstelle zum Erzeuger der
/// Importdatei: Er wird kopiert, in ein anderes Programm gegeben und dort
/// befolgt: was hier fehlt, fehlt in der Datei. Geprüft wird deshalb nicht der
/// Wortlaut, sondern dass die vier Aussagen darin stehen, ohne die ein
/// Arbeitspaket schadet statt nützt.
void main() {
  test('der Auftrag beschreibt den Dateiaufbau, den die Seite zeigt', () {
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

  // Es gab einmal einen zweiten Auftrag für den Lauf über den ganzen
  // Stammordner, ohne Paket. Zwei Aufträge nebeneinander ließen offen, welcher
  // gilt; der schwächere ist gegangen. Was ihn ausmachte — ein von Hand zu
  // füllender Stammordner-Platzhalter statt der Ordner aus dem Paket —, darf
  // im verbliebenen nicht wieder auftauchen.
  test('der Auftrag kennt nur den Weg über ein Arbeitspaket', () {
    expect(ImportAnleitung.paketText, contains('arbeitspaket-<nr>.json'));
    expect(ImportAnleitung.paketText, isNot(contains('hier eintragen')));
  });
}
