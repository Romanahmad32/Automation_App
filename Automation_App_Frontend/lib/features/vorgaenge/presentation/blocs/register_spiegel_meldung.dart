import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';

/// Was nach einem Druck auf „Register jetzt schreiben" als flüchtige Meldung
/// erscheint (§6.2).
///
/// Eigene Klasse, damit in der Seite der Ablauf steht und nicht der Wortlaut —
/// und damit die vier Ausgänge eines Laufs an einer Stelle beieinanderstehen:
/// geschrieben, geschrieben ohne PDF, aus einem Grund nicht geschrieben,
/// gescheitert. Nur so ist ihnen anzusehen, dass jeder von ihnen sagt, woran
/// man ist.
///
/// Vorher stand der Fehlschlag als roter Satz am **Fuß** der Seite, unter
/// tausenden Zeilen: Wer oben auf den Knopf gedrückt hatte, sah dort nichts.
class RegisterSpiegelMeldung {
  final RueckmeldungsArt art;
  final String text;

  const RegisterSpiegelMeldung({required this.art, required this.text});

  /// Die Meldung zu einem Ergebnis. [RegisterSpiegelErgebnis.fehler] trägt
  /// bereits einen deutschen Satz — der Dienst sagt „Die Datei ist noch in Word
  /// geöffnet" und nicht einen Ausnahmetext, und die Datenquelle übersetzt,
  /// was gar nicht erst ankam.
  factory RegisterSpiegelMeldung.zu(RegisterSpiegelErgebnis ergebnis) {
    if (ergebnis.fehler != null) {
      return RegisterSpiegelMeldung(
        art: RueckmeldungsArt.fehler,
        text: ergebnis.fehler!,
      );
    }
    if (ergebnis.geschrieben) {
      final pdf = ergebnis.pdfFehler;
      if (pdf != null) {
        return RegisterSpiegelMeldung(
          art: RueckmeldungsArt.hinweis,
          text: 'Das Register ist geschrieben, das PDF daneben nicht: $pdf',
        );
      }
      return RegisterSpiegelMeldung(
        art: RueckmeldungsArt.erfolg,
        text:
            'Register geschrieben — ${ergebnis.zeilen} '
            '${ergebnis.zeilen == 1 ? 'Zeile' : 'Zeilen'}.',
      );
    }
    return RegisterSpiegelMeldung(
      art: RueckmeldungsArt.hinweis,
      text: ergebnis.grund ?? 'Es wurde nichts geschrieben.',
    );
  }

  /// Zeigt die Meldung in ihrer Art. Der Aufrufer hält den [Rueckmeldung]-Griff
  /// schon vor dem `await`, wie überall in der App.
  void zeige(Rueckmeldung rueckmeldung) => switch (art) {
    RueckmeldungsArt.erfolg => rueckmeldung.erfolg(text),
    RueckmeldungsArt.hinweis => rueckmeldung.hinweis(text),
    RueckmeldungsArt.fehler => rueckmeldung.fehler(text),
  };
}
