import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:injectable/injectable.dart';

/// Dateibasierter Zugriff auf das Aktensystem (§3.6) — reines `dart:io`, analog
/// zum bisherigen Speicherschritt. Der Stammordner wird als Parameter
/// übergeben, damit die Klasse zustandslos bleibt (das Repository liest ihn aus
/// den Einstellungen).
@injectable
class AktenFilesystemDatasource {
  const AktenFilesystemDatasource();

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

  /// Legt [quelldateiPfad] in `<stammordner>/<ordnername>/<unterordnerName>/`
  /// ab. Akten- und Unterordner werden bei Bedarf angelegt. Gibt den Zielpfad
  /// der Kopie zurück.
  Future<String> legeDokumentAb({
    required String stammordner,
    required String ordnername,
    required String unterordnerName,
    required String quelldateiPfad,
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
    final quelle = File(quelldateiPfad);
    if (!await quelle.exists()) {
      throw MandantException('Quelldatei nicht gefunden: $quelldateiPfad');
    }

    final unterordner = Directory(
      _join(_join(basis, ordnername), unterordnerName),
    );
    await unterordner.create(recursive: true);

    final ziel = _join(unterordner.path, _basename(quelldateiPfad));
    await quelle.copy(ziel);
    return ziel;
  }

  String _join(String a, String b) {
    final sep = Platform.pathSeparator;
    final left = a.endsWith(sep) || a.endsWith('/')
        ? a.substring(0, a.length - 1)
        : a;
    return '$left$sep$b';
  }

  String _basename(String path) => path.split(RegExp(r'[\\/]')).last;
}
