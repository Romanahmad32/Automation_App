import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:equatable/equatable.dart';

/// Eine Akte = ein Mandanten-Ordner direkt unter dem Stammordner des
/// Aktensystems (§3.6). Reine Laufzeit-Sicht des Dateisystems (gescannt, nicht
/// persistiert); die strukturierten Mandantendaten liegen separat im
/// Mandantenregister und werden über den Ordnernamen verknüpft.
class Akte extends Equatable {
  /// Ordnername direkt unter dem Stammordner (z. B. „VUnfallursache Mark").
  final String ordnername;

  /// Vollständiger Pfad des Akten-Ordners.
  final String pfad;

  /// Die Fälle (Unterordner) der Akte, zuletzt geänderte zuerst.
  final List<Fall> faelle;

  const Akte({
    required this.ordnername,
    required this.pfad,
    this.faelle = const [],
  });

  @override
  List<Object?> get props => [ordnername, pfad, faelle];
}
