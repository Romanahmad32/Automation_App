import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_art.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_meldung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was nach „Register jetzt schreiben" oben rechts erscheint (§6.2).
///
/// Vorher stand das Ergebnis nur in der Leiste am **Fuß** der Seite — wer oben
/// gedrückt hatte, sah unter tausenden Zeilen nichts davon, und der Fehlschlag
/// trug den Ausnahmetext von Dio im Wortlaut.
void main() {
  test('ein Fehlschlag ist ein Fehler und trägt den Satz des Dienstes', () {
    final meldung = RegisterSpiegelMeldung.zu(
      const RegisterSpiegelErgebnis(
        fehler: 'Die Datei ist noch in Word geöffnet.',
      ),
    );

    expect(meldung.art, RueckmeldungsArt.fehler);
    expect(meldung.text, 'Die Datei ist noch in Word geöffnet.');
  });

  test('ein geschriebener Spiegel meldet sich als Erfolg mit Umfang', () {
    final meldung = RegisterSpiegelMeldung.zu(
      const RegisterSpiegelErgebnis(
        geschrieben: true,
        docxPfad: r'C:\Register\Register.docx',
        zeilen: 1284,
      ),
    );

    expect(meldung.art, RueckmeldungsArt.erfolg);
    expect(meldung.text, contains('1284 Zeilen'));
  });

  /// Auf einem Rechner ohne Word ist das erwartbar und kein Fehlschlag: Die
  /// `.docx` ist die verbindliche Fassung, das PDF die bequeme.
  test('ein fehlendes PDF ist ein Hinweis, kein Fehler', () {
    final meldung = RegisterSpiegelMeldung.zu(
      const RegisterSpiegelErgebnis(
        geschrieben: true,
        docxPfad: r'C:\Register\Register.docx',
        pdfFehler: 'Word ist auf diesem Rechner nicht installiert.',
        zeilen: 3,
      ),
    );

    expect(meldung.art, RueckmeldungsArt.hinweis);
    expect(meldung.text, contains('nicht installiert'));
  });

  /// „Kein Ablageordner eingestellt" ist keine Panne, sondern eine Auskunft —
  /// und der Grund des Dienstes sagt sie besser als ein eigener Satz.
  test('ein übersprungener Lauf nennt seinen Grund als Hinweis', () {
    final meldung = RegisterSpiegelMeldung.zu(
      const RegisterSpiegelErgebnis(
        grund: 'Es ist kein Ablageordner für das Register eingestellt.',
      ),
    );

    expect(meldung.art, RueckmeldungsArt.hinweis);
    expect(meldung.text, startsWith('Es ist kein Ablageordner'));
  });

  test('ohne jede Auskunft bleibt ein verständlicher Satz übrig', () {
    final meldung = RegisterSpiegelMeldung.zu(
      RegisterSpiegelErgebnis.unbekannt,
    );

    expect(meldung.art, RueckmeldungsArt.hinweis);
    expect(meldung.text, 'Es wurde nichts geschrieben.');
  });
}
