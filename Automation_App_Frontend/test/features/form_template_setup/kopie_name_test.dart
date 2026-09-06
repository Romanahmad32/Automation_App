import 'package:automation_app/features/form_template_setup/domain/services/kopie_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Name, unter dem eine duplizierte Vorlage angelegt wird (#104 Stufe 4).
///
/// Die Namenseindeutigkeit erzwingt das Backend mit 409 — der Vorschlag hier
/// soll dafür sorgen, dass der Anwalt diesen Fehler nie zu sehen bekommt.
void main() {
  test('freier Name: schlicht „(Kopie)"', () {
    expect(
      KopieName.fuer('Anspruchsschreiben', const ['Anspruchsschreiben']),
      'Anspruchsschreiben (Kopie)',
    );
  });

  test('belegter Name: „(Kopie 2)"', () {
    expect(
      KopieName.fuer('Anspruchsschreiben', const [
        'Anspruchsschreiben',
        'Anspruchsschreiben (Kopie)',
      ]),
      'Anspruchsschreiben (Kopie 2)',
    );
  });

  test('mehrfach belegt: zählt weiter, ohne Lücke zu suchen', () {
    expect(
      KopieName.fuer('Anspruchsschreiben', const [
        'Anspruchsschreiben',
        'Anspruchsschreiben (Kopie)',
        'Anspruchsschreiben (Kopie 2)',
        'Anspruchsschreiben (Kopie 3)',
      ]),
      'Anspruchsschreiben (Kopie 4)',
    );
  });

  test('das Original heißt schon „(Kopie)" — kein „(Kopie) (Kopie)"', () {
    // Die Kopie einer Kopie zählt am selben Stamm weiter. Sonst wüchse mit
    // jedem Klick ein Wortstapel, in dem niemand mehr die Vorlage erkennt.
    expect(
      KopieName.fuer('Anspruchsschreiben (Kopie)', const [
        'Anspruchsschreiben',
        'Anspruchsschreiben (Kopie)',
      ]),
      'Anspruchsschreiben (Kopie 2)',
    );
  });

  test('das Original heißt schon „(Kopie 2)" — derselbe Stamm', () {
    expect(
      KopieName.fuer('Anspruchsschreiben (Kopie 2)', const [
        'Anspruchsschreiben',
        'Anspruchsschreiben (Kopie)',
        'Anspruchsschreiben (Kopie 2)',
      ]),
      'Anspruchsschreiben (Kopie 3)',
    );
  });

  test('Groß-/Kleinschreibung und Randleerzeichen zählen nicht', () {
    // Zwei Vorlagen, die sich nur in der Schreibweise unterscheiden, wären für
    // den Anwalt dieselbe — der Vorschlag weicht ihnen aus, auch wenn das
    // Backend sie nebeneinander duldete.
    expect(
      KopieName.fuer('Anspruchsschreiben', const [
        '  anspruchsschreiben (KOPIE)  ',
      ]),
      'Anspruchsschreiben (Kopie 2)',
    );
  });

  test('leerer Bestand: der Vorschlag steht trotzdem', () {
    expect(KopieName.fuer('Mahnung', const []), 'Mahnung (Kopie)');
  });
}
