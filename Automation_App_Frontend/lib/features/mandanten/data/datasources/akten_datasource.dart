import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:injectable/injectable.dart';

/// Dateibasierter Zugriff auf das Aktensystem (§6.1) — reines `dart:io`, analog
/// zum bisherigen Speicherschritt. Der Stammordner wird als Parameter
/// übergeben, damit die Klasse zustandslos bleibt (das Repository liest ihn aus
/// den Einstellungen).
@injectable
class FilesystemAktenDatasource {
  const FilesystemAktenDatasource();

  /// Scannt den Stammordner: jeder direkte Unterordner ist eine Akte, dessen
  /// Unterordner sind die Fälle. Leere Liste, wenn [stammordner] leer ist oder
  /// nicht existiert (kein Fehler — der Nutzer hat ihn evtl. noch nicht gesetzt).
  Future<List<Akte>> scanAkten(String stammordner) async {
    final pfad = stammordner.trim();
    if (pfad.isEmpty) return const [];
    final wurzel = Directory(pfad);
    if (!await wurzel.exists()) return const [];

    final akten = <Akte>[];
    await for (final eintrag in wurzel.list(followLinks: false)) {
      if (eintrag is! Directory) continue;
      final ordnername = _basename(eintrag.path);
      akten.add(
        Akte(
          ordnername: ordnername,
          pfad: eintrag.path,
          faelle: await _scanFaelle(eintrag),
        ),
      );
    }
    akten.sort(
      (a, b) =>
          a.ordnername.toLowerCase().compareTo(b.ordnername.toLowerCase()),
    );
    return akten;
  }

  Future<List<Fall>> _scanFaelle(Directory akte) async {
    final faelle = <Fall>[];
    await for (final eintrag in akte.list(followLinks: false)) {
      if (eintrag is! Directory) continue;
      final dokumente = <String>[];
      await for (final datei in eintrag.list(followLinks: false)) {
        if (datei is File) dokumente.add(datei.path);
      }
      faelle.add(
        Fall(
          name: _basename(eintrag.path),
          pfad: eintrag.path,
          geaendertAm: (await eintrag.stat()).modified,
          dokumente: dokumente..sort(),
        ),
      );
    }
    // Zuletzt geänderte Fälle zuerst.
    faelle.sort((a, b) => b.geaendertAm.compareTo(a.geaendertAm));
    return faelle;
  }

  /// Legt [quelldateiPfade] — alle Fassungen **eines** Schreibens — in
  /// `<stammordner>/<ordnername>/<unterordnerName>/` ab. Akten- und
  /// Unterordner werden bei Bedarf angelegt.
  ///
  /// Liegt dort schon eine gleichnamige Datei, entscheidet [strategie], und
  /// zwar für den ganzen Satz auf einmal: Der Standard schreibt **nichts** und
  /// meldet die vorhandenen Dateien zurück (in der Akte steht die verbindliche
  /// Fassung, und `File.copy` ersetzt sie kommentarlos), `beideBehalten`
  /// nummeriert alle Fassungen gemeinsam.
  Future<AblageErgebnis> legeDokumentAb({
    required String stammordner,
    required String ordnername,
    required String unterordnerName,
    required List<String> quelldateiPfade,
    AblageStrategie strategie = AblageStrategie.fragen,
  }) async {
    final basis = stammordner.trim();
    if (basis.isEmpty) {
      throw const MandantException(
        'Kein Stammordner gesetzt — bitte in den Einstellungen festlegen.',
      );
    }
    if (!await Directory(basis).exists()) {
      throw MandantException('Stammordner existiert nicht: $basis');
    }
    for (final pfad in quelldateiPfade) {
      if (!await File(pfad).exists()) {
        throw MandantException('Quelldatei nicht gefunden: $pfad');
      }
    }

    final unterordner = Directory(
      _join(_join(basis, ordnername), unterordnerName),
    );
    await unterordner.create(recursive: true);

    // Erneut abgelegt, ohne den Ordner zu wechseln: die Datei liegt bereits
    // dort, wo sie hinsoll. Ein copy() auf sich selbst wäre ein Fehler, kein
    // Fortschritt — möglich, seit der Wizard nach der Ablage mit der Kopie in
    // der Akte weiterarbeitet. Solche Dateien sind fertig und bleiben aus der
    // Konflikt- und Nummernrechnung heraus.
    final schonAmPlatz = <String>[];
    final zuKopieren = <String>[];
    for (final quelle in quelldateiPfade) {
      final ziel = _join(unterordner.path, _basename(quelle));
      (_gleicherPfad(quelle, ziel) ? schonAmPlatz : zuKopieren).add(quelle);
    }

    var ziele = [
      for (final quelle in zuKopieren)
        _join(unterordner.path, _basename(quelle)),
    ];
    final vorhanden = [
      for (final ziel in ziele)
        if (await File(ziel).exists()) ziel,
    ];

    if (vorhanden.isNotEmpty) {
      switch (strategie) {
        case AblageStrategie.fragen:
          return AblageErgebnis.konfliktMit(vorhanden);
        case AblageStrategie.beideBehalten:
          ziele = await _naechsterFreierSatz(ziele);
        case AblageStrategie.ersetzen:
          break;
      }
    }

    for (var i = 0; i < zuKopieren.length; i++) {
      await File(zuKopieren[i]).copy(ziele[i]);
    }
    return AblageErgebnis.abgelegt([...schonAmPlatz, ...ziele]);
  }

  /// „Brief.docx" + „Brief.pdf" → „Brief (2).docx" + „Brief (2).pdf" — die
  /// erste Nummer, unter der **keines** der Ziele belegt ist. Nur für
  /// [AblageStrategie.beideBehalten]: hier ist die Zweitfassung ausdrücklich
  /// gewollt.
  ///
  /// Eine gemeinsame Nummer, weil die Fassungen zusammengehören: getrennt
  /// gezählt hieße die Word-Datei „(2)" und das PDF gar nichts, und niemand
  /// sähe ihnen noch an, dass sie dasselbe Schreiben sind.
  Future<List<String>> _naechsterFreierSatz(List<String> ziele) async {
    for (var nummer = 2; ; nummer++) {
      final kandidaten = [for (final ziel in ziele) _mitNummer(ziel, nummer)];
      var frei = true;
      for (final kandidat in kandidaten) {
        if (await File(kandidat).exists()) {
          frei = false;
          break;
        }
      }
      if (frei) return kandidaten;
    }
  }

  String _mitNummer(String pfad, int nummer) {
    final name = _basename(pfad);
    final ordner = pfad.substring(0, pfad.length - name.length);
    final punkt = name.lastIndexOf('.');
    final stamm = punkt <= 0 ? name : name.substring(0, punkt);
    final endung = punkt <= 0 ? '' : name.substring(punkt);
    return '$ordner$stamm ($nummer)$endung';
  }

  String _join(String a, String b) {
    final sep = Platform.pathSeparator;
    final left = a.endsWith(sep) || a.endsWith('/')
        ? a.substring(0, a.length - 1)
        : a;
    return '$left$sep$b';
  }

  String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

  /// Windows-Pfade vergleichen: weder Groß-/Kleinschreibung noch die Wahl des
  /// Trennzeichens unterscheiden zwei Dateien voneinander.
  bool _gleicherPfad(String a, String b) =>
      a.replaceAll('/', r'\').toLowerCase() ==
      b.replaceAll('/', r'\').toLowerCase();
}
