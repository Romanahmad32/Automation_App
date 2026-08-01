import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:injectable/injectable.dart';

/// Schmale Schnittstelle für den Export der abgeschlossenen Vorgänge in das
/// echte, mehrseitige Sachgebiete-Register der Kanzlei (Word-Tabelle: laufende
/// Nr | Aktenzeichen Abteilung | Name ./. Gegner + Sachbestand v. Datum |
/// Rechtsgebiet).
///
/// Solange die reale Registervorlage nicht vorliegt, bleibt der Export hinter
/// dieser Schnittstelle deaktiviert ([verfuegbar] == false). Die In-App-Ansicht
/// zeigt die Daten bereits im exakten Spaltenschema; sobald die Vorlage da ist,
/// wird hier eine echte Implementierung registriert, ohne dass die Ansicht sich
/// ändern muss.
abstract class RegisterWordExporter {
  /// Ob der Word-Export bereits möglich ist.
  bool get verfuegbar;

  /// Schreibt die [abgeschlossene]n Vorgänge als Registerzeilen in das
  /// Word-Dokument. Wirft, solange [verfuegbar] false ist.
  Future<void> exportiere(List<Vorgang> abgeschlossene);
}

/// Platzhalter, bis die mehrseitige Registervorlage der Kanzlei vorliegt.
@LazySingleton(as: RegisterWordExporter)
class NichtVerfuegbarerRegisterWordExporter implements RegisterWordExporter {
  @override
  bool get verfuegbar => false;

  @override
  Future<void> exportiere(List<Vorgang> abgeschlossene) {
    throw UnsupportedError(
      'Der Word-Export ins Sachgebiete-Register ist noch nicht verfügbar. '
      'Er wird aktiviert, sobald die Registervorlage der Kanzlei vorliegt.',
    );
  }
}
