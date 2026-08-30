import 'dart:io';

import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft den Vorschlag für die Register-Ablage (§6.2).
///
/// Der Punkt dieser Klasse ist, was sie **nicht** tut: Sie meldet sich bei
/// keiner Cloud an und kennt kein Konto. Sie liest die Umgebungsvariablen, die
/// der OneDrive-Client selbst setzt, und schlägt einen ganz gewöhnlichen
/// Ordnerpfad vor.
void main() {
  String pfad(String basis) =>
      '$basis${Platform.pathSeparator}${SynchronisierterOrdner.unterordner}';

  test('schlägt einen Unterordner im synchronisierten Bereich vor', () {
    final vorschlag = SynchronisierterOrdner.vorschlag({
      'OneDrive': r'C:\Users\anwalt\OneDrive',
    });

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive'));
  });

  /// Wer beides eingerichtet hat, meint mit „meinem OneDrive" das der Kanzlei.
  test('nimmt das Geschäftskonto vor dem privaten', () {
    final vorschlag = SynchronisierterOrdner.vorschlag({
      'OneDrive': r'C:\Users\anwalt\OneDrive',
      'OneDriveConsumer': r'C:\Users\anwalt\OneDrive-privat',
      'OneDriveCommercial': r'C:\Users\anwalt\OneDrive - Kanzlei',
    });

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive - Kanzlei'));
  });

  test('überspringt leere Variablen', () {
    final vorschlag = SynchronisierterOrdner.vorschlag({
      'OneDriveCommercial': '   ',
      'OneDrive': r'C:\Users\anwalt\OneDrive',
    });

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive'));
  });

  /// Ohne erkannten Ordner erscheint der Vorschlag gar nicht — die App drängt
  /// niemanden in die Cloud, sie spart nur das Suchen im Ordnerdialog.
  test('liefert nichts, wenn kein synchronisierter Ordner erkennbar ist', () {
    expect(SynchronisierterOrdner.vorschlag(const {}), isNull);
  });
}
