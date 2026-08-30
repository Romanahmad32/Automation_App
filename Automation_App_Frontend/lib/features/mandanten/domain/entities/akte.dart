import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';
import 'package:equatable/equatable.dart';

/// Eine Akte = ein Mandanten-Ordner direkt unter dem Stammordner des
/// Aktensystems (§6.1). Reine Laufzeit-Sicht des Dateisystems (gescannt, nicht
/// persistiert); die strukturierten Mandantendaten liegen separat im
/// Mandantenregister und werden über den Ordnernamen verknüpft.
class Akte extends Equatable {
  /// Ordnername direkt unter dem Stammordner (z. B. „VUnfallursache Mark").
  final String ordnername;

  /// Vollständiger Pfad des Akten-Ordners.
  final String pfad;

  /// Änderungszeitpunkt des Akten-Ordners. Kommt aus dem flachen Scan und
  /// trägt den Filter „geändert seit …": abgeschlossene Altakten gehören nicht
  /// in den Zuordnungsstapel.
  final DateTime? geaendertAm;

  /// Die Fälle (Unterordner) der Akte, zuletzt geänderte zuerst. Leer, solange
  /// [faelleGeladen] `false` ist — der Erst-Scan liest sie nicht mit.
  final List<Fall> faelle;

  /// Ob die Fälle schon nachgeladen wurden. Trennt „noch nicht gelesen" von
  /// „gelesen, es gibt keine": ohne diese Unterscheidung stünde an jeder Akte
  /// „0 Fälle", bis jemand sie aufklappt.
  final bool faelleGeladen;

  const Akte({
    required this.ordnername,
    required this.pfad,
    this.geaendertAm,
    this.faelle = const [],
    this.faelleGeladen = false,
  });

  /// Aktentyp aus dem Präfix des Ordnernamens — die Grundlage dafür, dass
  /// Bußgeld-, Straf- und Familiensachen nicht im Zuordnungsstapel landen.
  Aktentyp get aktentyp => AktentypErkennung.typVon(ordnername);

  Akte mitFaellen(List<Fall> faelle) => Akte(
    ordnername: ordnername,
    pfad: pfad,
    geaendertAm: geaendertAm,
    faelle: faelle,
    faelleGeladen: true,
  );

  @override
  List<Object?> get props => [
    ordnername,
    pfad,
    geaendertAm,
    faelle,
    faelleGeladen,
  ];
}
