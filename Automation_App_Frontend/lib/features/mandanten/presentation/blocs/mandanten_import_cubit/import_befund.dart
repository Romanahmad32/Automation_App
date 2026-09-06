import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/import_aehnlichkeit.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/ordner_pruefung.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/import_umfeld.dart';
import 'package:equatable/equatable.dart';

/// Was die Oberfläche über den Bericht des Dienstes hinaus über die Datei
/// weiß: welche Zeilen einen Ordner nennen, den es nicht gibt, und zu welchen
/// Zeilen ein ähnlicher Name schon im Register steht.
///
/// Gerechnet wird **einmal je Bericht** im Cubit und nicht beim Bauen der
/// Liste. Der Ähnlichkeitsvergleich geht über die ganze Vorschau; ihn an jede
/// gebaute Kachel oder an jeden Tastendruck im Suchfeld zu hängen hieße, ihn
/// bei viertausend Zeilen dutzendfach zu wiederholen.
///
/// Beides sind **Auskünfte**, keine zweite Auslegung der Importregeln: was die
/// Datei bewirkt, sagt weiterhin allein der Dienst. Der einzige Eingriff ist
/// die Sperre — und die hält nur auf, sie entscheidet nichts.
class ImportBefund extends Equatable {
  /// Zeilennummern (Index in `datei.mandanten`), die mindestens einen Ordner
  /// nennen, den es im Stammordner nicht gibt.
  final Set<int> unbekannteZeilen;

  /// Dasselbe für die Ordner unter „ohne Mandantenbezug". Sie sind keine
  /// Zeilen der Liste und brauchen deshalb einen eigenen Platz.
  final List<String> unbekannteOhneBezug;

  /// Ähnliche Registereinträge je Zeilennummer. Zeilen ohne Fund fehlen in der
  /// Karte, statt leer darin zu stehen.
  final Map<int, List<MandantVorschlag>> aehnliche;

  const ImportBefund({
    this.unbekannteZeilen = const {},
    this.unbekannteOhneBezug = const [],
    this.aehnliche = const {},
  });

  /// Solange eine unbekannte Ordnerangabe in der Datei steht, wird nicht
  /// geschrieben.
  ///
  /// Ein erfundener Ordnername ist schlimmer als eine fehlende Zuordnung: Er
  /// wird klaglos gespeichert, der Ordner ist danach nie auffindbar, die
  /// Mandantenkarte zeigt eine Akte, die es nicht gibt — und der
  /// Zuordnungsstapel zählt sie als erledigt. Von Hand zurückdrehen lässt sich
  /// das kaum noch, weil nichts davon nach einem Fehler aussieht. Der Anwalt
  /// berichtigt die Zeile im Dialog oder lässt sie weg; beides kostet ihn
  /// weniger als die Suche nach einem Ordner, den es nie gab.
  bool get sperrtUebernahme =>
      unbekannteZeilen.isNotEmpty || unbekannteOhneBezug.isNotEmpty;

  /// Die Befunde zu einer geprüften Datei. [bericht] und [datei] stammen aus
  /// demselben Aufruf — nur dann zeigen Zeilennummer und Vorschlag auf
  /// dasselbe.
  ///
  /// Der Fall „kein Scan vorhanden" wird nicht hier abgefangen, sondern in
  /// `OrdnerPruefung.istBekannt`: eine zweite Fassung derselben Regel liefe
  /// beim ersten Sonderfall auseinander.
  static ImportBefund zu({
    required ImportUmfeld umfeld,
    required MandantenImportDatei datei,
    required ImportBericht bericht,
  }) {
    final vorhandene = umfeld.menge;
    return ImportBefund(
      unbekannteZeilen: OrdnerPruefung.unbekannteZeilen(
        datei: datei,
        vorhandene: vorhandene,
      ),
      unbekannteOhneBezug: OrdnerPruefung.unbekannteOhneBezug(
        datei: datei,
        vorhandene: vorhandene,
      ),
      aehnliche: ImportAehnlichkeit.zuVorschau(
        bericht: bericht,
        datei: datei,
        mandanten: umfeld.mandanten,
      ),
    );
  }

  @override
  List<Object?> get props => [unbekannteZeilen, unbekannteOhneBezug, aehnliche];
}
