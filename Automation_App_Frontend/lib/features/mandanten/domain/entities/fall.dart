import 'package:equatable/equatable.dart';

/// Ein einzelner Fall/Vorgang innerhalb einer Akte — entspricht einem
/// Unterordner im Akten-Ordner (z. B. „Unfall v. 12.05.2019"). Reine
/// Laufzeit-Sicht des Dateisystems, wird nicht persistiert.
class Fall extends Equatable {
  /// Ordnername des Unterordners (ohne Pfad).
  final String name;

  /// Vollständiger Pfad des Unterordners.
  final String pfad;

  /// Änderungszeitpunkt des Ordners (für Sortierung „zuletzt zuerst").
  final DateTime geaendertAm;

  /// Vollständige Pfade der Dateien direkt im Fall-Ordner (z. B. das fertige
  /// Anspruchsschreiben).
  final List<String> dokumente;

  const Fall({
    required this.name,
    required this.pfad,
    required this.geaendertAm,
    this.dokumente = const [],
  });

  @override
  List<Object?> get props => [name, pfad, geaendertAm, dokumente];
}
