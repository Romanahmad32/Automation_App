import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter_test/flutter_test.dart';

/// „heute um 14:12" statt „01.09.2026 um 14:12" (§7.2): Beim Start geht es um
/// die Frage, ob der andere Arbeitsplatz gerade eben dran war oder vor Wochen.
/// Ein Datum muss man dafür erst mit dem heutigen vergleichen.
void main() {
  final jetzt = DateTime(2026, 9, 1, 9, 30);

  test('nennt heute und gestern beim Namen', () {
    expect(
      SicherungsZeitpunkt.beschreibe(DateTime(2026, 9, 1, 8, 5), jetzt: jetzt),
      'heute um 08:05',
    );
    expect(
      SicherungsZeitpunkt.beschreibe(
        DateTime(2026, 8, 31, 14, 12),
        jetzt: jetzt,
      ),
      'gestern um 14:12',
    );
  });

  /// Nicht „vor 21 Stunden": Der Grenzfall ist der Feierabend. Wer um 18:04
  /// aufhört und am nächsten Morgen um 9:30 wieder anfängt, hat *gestern*
  /// gearbeitet — auch wenn dazwischen keine 24 Stunden liegen.
  test('rechnet in Kalendertagen, nicht in Stunden', () {
    expect(
      SicherungsZeitpunkt.beschreibe(
        DateTime(2026, 8, 31, 18, 4),
        jetzt: jetzt,
      ),
      'gestern um 18:04',
    );
  });

  test('nennt bei älteren Ständen das Datum', () {
    expect(
      SicherungsZeitpunkt.beschreibe(DateTime(2026, 8, 28, 7, 9), jetzt: jetzt),
      'am 28.08.2026 um 07:09',
    );
  });
}
