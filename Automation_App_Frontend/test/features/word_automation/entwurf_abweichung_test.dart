import 'package:automation_app/features/word_automation/domain/services/entwurf_abweichung.dart';
import 'package:flutter_test/flutter_test.dart';

/// #133: Am Vorgang liegt nur, was von der Vorbelegung **abweicht** — sonst
/// fröre der angefangene Stand die Vorbelegung ein und verdeckte eine später
/// eintreffende Zentralruf-Antwort. Die Rechnung dahinter steht hier: ohne
/// Cubit, ohne Widget, damit jeder Grenzfall einzeln benennbar bleibt.
void main() {
  test('gleiche Werte kommen nicht in den Entwurf', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': 'HUK-COBURG', 'Schadennummer': '4711'},
      vorbelegung: const {'Versicherer': 'HUK-COBURG', 'Schadennummer': '4711'},
    );

    expect(abweichend, isEmpty);
  });

  test('nur das geänderte Feld bleibt übrig', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': 'Allianz', 'Schadennummer': '4711'},
      vorbelegung: const {'Versicherer': 'HUK-COBURG', 'Schadennummer': '4711'},
    );

    expect(abweichend, {'Versicherer': 'Allianz'});
  });

  test('ein Feld ohne Vorbelegung zählt gegen den leeren Wert', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': 'Allianz'},
      vorbelegung: const {},
    );

    expect(abweichend, {'Versicherer': 'Allianz'});
  });

  test('ein leeres Feld ohne Vorbelegung ist keine Abweichung', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': '', 'Schadennummer': '   '},
      vorbelegung: const {},
    );

    expect(abweichend, isEmpty);
  });

  /// „Ich will hier nichts stehen haben" ist eine Entscheidung — ohne sie käme
  /// die Vorbelegung bei der Rückkehr wieder.
  test('ein geleertes vorbelegtes Feld bleibt im Entwurf', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': ''},
      vorbelegung: const {'Versicherer': 'HUK-COBURG'},
    );

    expect(abweichend, {'Versicherer': ''});
  });

  test('Leerzeichen am Rand sind keine Abweichung', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': '  HUK-COBURG '},
      vorbelegung: const {'Versicherer': 'HUK-COBURG '},
    );

    expect(abweichend, isEmpty);
  });

  /// Gestutzt wird nur **verglichen**: Was aufgehoben wird, soll bei der
  /// Rückkehr Zeichen für Zeichen wieder dastehen.
  test('der aufgehobene Wert bleibt ungestutzt', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {'Versicherer': ' Allianz '},
      vorbelegung: const {'Versicherer': 'HUK-COBURG'},
    );

    expect(abweichend, {'Versicherer': ' Allianz '});
  });

  /// Der Entwurf darf Felder einer **anderen** Vorlage tragen; gemeldet wird
  /// hier aber nur, was im Formular steht. Was nicht gemeldet wurde, kann auch
  /// nicht abweichen — das Zusammenführen mit dem Bestand macht der Cubit.
  test('was nicht gemeldet wurde, taucht nicht auf', () {
    final abweichend = EntwurfAbweichung.nurAbweichende(
      werte: const {},
      vorbelegung: const {'Versicherer': 'HUK-COBURG'},
    );

    expect(abweichend, isEmpty);
  });
}
