import 'dart:io';

import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft den Vorschlag für die Register-Ablage (§6.2).
///
/// Der Punkt dieser Klasse ist, was sie **nicht** tut: Sie meldet sich bei
/// keiner Cloud an und kennt kein Konto. Sie liest die Umgebungsvariablen, die
/// der OneDrive-Client selbst setzt, und schlägt einen ganz gewöhnlichen
/// Ordnerpfad vor.
///
/// Die Existenzprüfung wird hier eingesetzt statt umgangen. Vorher hing sie
/// daran, dass keine Umgebung übergeben wurde — die Tests fuhren damit einen
/// Zweig, den es im Betrieb nie gibt, und „der Ordner steht in der Variable,
/// liegt aber nicht auf der Platte" war ungeprüft.
void main() {
  String pfad(String basis) =>
      '$basis${Platform.pathSeparator}${SynchronisierterOrdner.registerUnterordner}';

  /// Alle Ordner liegen da. Die Prüfung merkt sich, wonach gefragt wurde.
  Future<bool> Function(String) alleDa(List<String> gefragt) => (pfad) async {
    gefragt.add(pfad);
    return true;
  };

  test('schlägt einen Unterordner im synchronisierten Bereich vor', () async {
    final vorschlag = await SynchronisierterOrdner.suche(
      umgebung: {'OneDrive': r'C:\Users\anwalt\OneDrive'},
      existiert: alleDa([]),
    );

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive'));
  });

  /// Wer beides eingerichtet hat, meint mit „meinem OneDrive" das der Kanzlei.
  test('nimmt das Geschäftskonto vor dem privaten', () async {
    final vorschlag = await SynchronisierterOrdner.suche(
      umgebung: {
        'OneDrive': r'C:\Users\anwalt\OneDrive',
        'OneDriveConsumer': r'C:\Users\anwalt\OneDrive-privat',
        'OneDriveCommercial': r'C:\Users\anwalt\OneDrive - Kanzlei',
      },
      existiert: alleDa([]),
    );

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive - Kanzlei'));
  });

  test('überspringt leere Variablen, ohne nach ihnen zu sehen', () async {
    final gefragt = <String>[];

    final vorschlag = await SynchronisierterOrdner.suche(
      umgebung: {
        'OneDriveCommercial': '   ',
        'OneDrive': r'C:\Users\anwalt\OneDrive',
      },
      existiert: alleDa(gefragt),
    );

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive'));
    expect(gefragt, [r'C:\Users\anwalt\OneDrive']);
  });

  /// Der Betriebszweig, der vorher nie lief: Die Variable ist gesetzt, der
  /// Ordner dahinter aber nicht da — ein Konto, das eingerichtet, aber nie
  /// synchronisiert wurde. Dann gilt die nächste Variable.
  test('überspringt einen Pfad, der nicht auf der Platte liegt', () async {
    final vorschlag = await SynchronisierterOrdner.suche(
      umgebung: {
        'OneDriveCommercial': r'C:\Users\anwalt\OneDrive - Kanzlei',
        'OneDrive': r'C:\Users\anwalt\OneDrive',
      },
      existiert: (pfad) async => !pfad.contains('Kanzlei'),
    );

    expect(vorschlag, pfad(r'C:\Users\anwalt\OneDrive'));
  });

  /// Ohne erkannten Ordner erscheint der Vorschlag gar nicht — die App drängt
  /// niemanden in die Cloud, sie spart nur das Suchen im Ordnerdialog.
  test(
    'liefert nichts, wenn kein synchronisierter Ordner erkennbar ist',
    () async {
      expect(
        await SynchronisierterOrdner.suche(
          umgebung: const {},
          existiert: alleDa([]),
        ),
        isNull,
      );
    },
  );

  test('liefert nichts, wenn keiner der Pfade auf der Platte liegt', () async {
    expect(
      await SynchronisierterOrdner.suche(
        umgebung: {'OneDrive': r'C:\Users\anwalt\OneDrive'},
        existiert: (_) async => false,
      ),
      isNull,
    );
  });

  /// Für den einen Ordner der App-Daten (#103) reicht der Pfad nicht: Zum
  /// relativ abgelegten Ordner gehört der Anker, sonst löst derselbe Pfad auf
  /// einem Rechner mit anderem Konto still in einem anderen Baum auf.
  test('liefert Wurzel und Variable, gegen die gerechnet wurde', () async {
    final wurzel = await SynchronisierterOrdner.sucheWurzel(
      umgebung: {'OneDriveConsumer': r'C:\Users\anwalt\OneDrive-privat'},
      existiert: alleDa([]),
    );

    expect(wurzel?.variable, 'OneDriveConsumer');
    expect(
      wurzel?.pfad,
      r'C:\Users\anwalt\OneDrive-privat',
      reason: 'Die Wurzel selbst, ohne Unterordner — den hängt suche() an.',
    );
  });

  test('nimmt auch bei der Wurzel das Geschäftskonto zuerst', () async {
    final wurzel = await SynchronisierterOrdner.sucheWurzel(
      umgebung: {
        'OneDrive': r'C:\Users\anwalt\OneDrive',
        'OneDriveConsumer': r'C:\Users\anwalt\OneDrive-privat',
        'OneDriveCommercial': r'C:\Users\anwalt\OneDrive - Kanzlei',
      },
      existiert: alleDa([]),
    );

    expect(wurzel?.variable, 'OneDriveCommercial');
    expect(wurzel?.pfad, r'C:\Users\anwalt\OneDrive - Kanzlei');
  });

  test('liefert keine Wurzel, wenn kein OneDrive erkennbar ist', () async {
    expect(
      await SynchronisierterOrdner.sucheWurzel(
        umgebung: const {},
        existiert: alleDa([]),
      ),
      isNull,
      reason:
          'Dann steht im Formular ein Hinweis statt eines Vorschlags — die App '
          'drängt niemanden in die Cloud.',
    );
  });

  /// Der Vorschlag für die eine Ordnerwahl: ein Ordner mit sprechendem Namen
  /// in der Wurzel der Synchronisierung, kein Unterordner eines Unterordners.
  test('schlägt den Ordner für die App-Daten in der Wurzel vor', () async {
    final vorschlag = await SynchronisierterOrdner.suche(
      unterordner: SynchronisierterOrdner.appDatenUnterordner,
      umgebung: {'OneDriveCommercial': r'C:\Users\anwalt\OneDrive - Kanzlei'},
      existiert: alleDa([]),
    );

    expect(
      vorschlag,
      r'C:\Users\anwalt\OneDrive - Kanzlei'
      '${Platform.pathSeparator}'
      'Kanzlei App Daten',
    );
  });

  /// Register-Spiegel und Sicherungen liegen im selben synchronisierten
  /// Bereich, aber nicht im selben Ordner: Das eine wird gelesen, das andere
  /// soll niemand anfassen (§7.2, #39).
  test('schlägt für die Sicherungen einen eigenen Unterordner vor', () async {
    final vorschlag = await SynchronisierterOrdner.suche(
      unterordner: SynchronisierterOrdner.sicherungenUnterordner,
      umgebung: {'OneDrive': r'C:\Users\anwalt\OneDrive'},
      existiert: alleDa([]),
    );

    expect(
      vorschlag,
      r'C:\Users\anwalt\OneDrive'
      '${Platform.pathSeparator}'
      '${SynchronisierterOrdner.sicherungenUnterordner}',
    );
    expect(vorschlag, isNot(pfad(r'C:\Users\anwalt\OneDrive')));
  });
}
