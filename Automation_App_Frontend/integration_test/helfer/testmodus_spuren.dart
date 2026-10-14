import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'e2e_umgebung.dart';

/// Eine Zeile aus `Testmodus\protokoll.jsonl` (#168): was eine Attrappe des
/// Dienstes an Stelle der echten Außenwirkung getan hat.
class ProtokollZeile {
  final String zeit;

  /// `zentralruf-anfrage`, `versand`, `gesendet-ablage`, `entwurf`, `druck`,
  /// `aktualisierung-installer` (#196).
  final String aktion;

  /// Nur die Zentralruf-Anfrage kennt ihren Vorgang; sonst `null`.
  final String? referenz;

  /// Die hinterlassene Datei relativ zum Testmodus-Ordner (mit `/`), oder null.
  final String? datei;

  const ProtokollZeile({
    required this.zeit,
    required this.aktion,
    this.referenz,
    this.datei,
  });

  factory ProtokollZeile.ausJson(Map<String, dynamic> json) => ProtokollZeile(
    zeit: json['zeit'] as String,
    aktion: json['aktion'] as String,
    referenz: json['referenz'] as String?,
    datei: json['datei'] as String?,
  );

  @override
  String toString() => '$aktion ${referenz ?? '-'} ${datei ?? '-'}';
}

/// Liest die Spuren des Testmodus-Dienstes: das Protokoll und die Dateien,
/// die Versand-, Entwurf- und Druck-Attrappe ablegen.
///
/// **Wiederholbar statt aufgeräumt:** Ein Durchlauf löscht nichts. Er merkt
/// sich vor dem ersten Schritt den [stand] und prüft danach nur die Zeilen,
/// die seitdem dazukamen ([seit]) — so laufen alle Durchläufe auf demselben
/// Ausgangsbestand nacheinander, auch zweimal.
class TestmodusSpuren {
  final String ordner;

  const TestmodusSpuren(this.ordner);

  /// Der Ordner aus `--dart-define=AUTOMATION_E2E_TESTMODUS_ORDNER`.
  factory TestmodusSpuren.ausUmgebung() =>
      TestmodusSpuren(E2eUmgebung.testmodusOrdner);

  File get protokoll => File(_pfad('protokoll.jsonl'));

  /// Alle Zeilen; ein fehlendes Protokoll heißt: noch nichts geschehen.
  List<ProtokollZeile> zeilen() {
    if (!protokoll.existsSync()) return const [];
    return [
      for (final zeile in protokoll.readAsLinesSync())
        if (zeile.trim().isNotEmpty)
          ProtokollZeile.ausJson(jsonDecode(zeile) as Map<String, dynamic>),
    ];
  }

  /// Die Zahl der Zeilen jetzt — die Marke für [seit].
  int stand() => zeilen().length;

  /// Die Zeilen, die nach der Marke [stand] dazugekommen sind.
  List<ProtokollZeile> seit(int stand) => zeilen().skip(stand).toList();

  /// Die seit [stand] protokollierten Zeilen mit der [aktion].
  List<ProtokollZeile> seitMitAktion(int stand, String aktion) =>
      seit(stand).where((zeile) => zeile.aktion == aktion).toList();

  /// Die Datei einer Protokollzeile; ein Testfehler, wenn sie keine nennt
  /// oder es sie nicht gibt.
  File datei(ProtokollZeile zeile) {
    final relativ = zeile.datei;
    if (relativ == null) fail('Die Zeile „$zeile" nennt keine Datei.');
    final datei = File(_pfad(relativ.replaceAll('/', r'\')));
    if (!datei.existsSync()) fail('Protokollierte Datei fehlt: ${datei.path}');
    return datei;
  }

  /// Ob [datei] ein ZIP-Archiv ist (beginnt mit „PK") — wie jede .docx.
  static bool istZipArchiv(File datei) {
    final zugriff = datei.openSync();
    try {
      final kopf = zugriff.readSync(2);
      return kopf.length == 2 && kopf[0] == 0x50 && kopf[1] == 0x4B;
    } finally {
      zugriff.closeSync();
    }
  }

  String _pfad(String relativ) => '$ordner${Platform.pathSeparator}$relativ';
}
