import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Dienst sendet Zeitpunkte mit Zeitzonenversatz (`+02:00`). Dart macht
/// daraus einen UTC-Wert — ohne `toLocal()` zeigte die Sicherungszeile
/// „17:19" für eine Sicherung um 19:19 Ortszeit. Der Test rechnet mit dem
/// Versatz des Rechners, damit er in jeder Zeitzone gilt.
void main() {
  test('Zeitpunkte mit Versatz kommen als Ortszeit an', () {
    final stand = UebergabeStand.fromJson({
      'angebot': {
        'rechnername': 'LAPTOP',
        'zuletztGearbeitet': '2026-09-05T19:19:28+02:00',
        'gesichertAm': '2026-09-05T19:19:28+02:00',
        'sicherung': 'automation-LAPTOP-20260905-191928.zip',
        'programmfassung': '1.0',
      },
      'eigenerStandGesichertAm': '2026-09-05T19:19:28+02:00',
      'letzteSicherung': {
        'zeitpunkt': '2026-09-05T19:19:28+02:00',
        'gelungen': true,
        'datei': 'automation-NB-20260905-191928.zip',
        'meldung': null,
        'fehlerQuittiert': false,
      },
      'ablageOrdner': r'C:\Sicherungen',
      'eigeneArchive': 4,
      'aeltestesArchiv': '2026-09-05T15:25:40',
    });

    final erwartet = DateTime.utc(2026, 9, 5, 17, 19, 28).toLocal();
    expect(stand.letzteSicherung!.zeitpunkt, erwartet);
    expect(stand.letzteSicherung!.zeitpunkt.isUtc, isFalse);
    expect(stand.eigenerStandGesichertAm, erwartet);
    expect(stand.angebot!.gesichertAm, erwartet);
    expect(stand.angebot!.zuletztGearbeitet, erwartet);

    // Ohne Versatz gesendet: bleibt der genannte Kalenderwert.
    expect(stand.aeltestesArchiv, DateTime(2026, 9, 5, 15, 25, 40));
    expect(stand.eigeneArchive, 4);
  });
}
