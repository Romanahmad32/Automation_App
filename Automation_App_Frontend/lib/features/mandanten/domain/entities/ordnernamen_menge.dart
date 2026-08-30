import 'package:equatable/equatable.dart';

/// Eine Menge von Ordnernamen, die **ohne Rücksicht auf Groß- und
/// Kleinschreibung** vergleicht.
///
/// Ordnernamen kommen aus dem Windows-Dateisystem, und dort sind
/// „VUnfallursache Mark" und „Vunfallursache Mark" derselbe Ordner — zwei
/// solche nebeneinander gibt es gar nicht. Genau verglichen hinge es an der
/// Schreibweise der Quelle, ob ein zugeordneter Ordner im Zuordnungsstapel
/// stehen bleibt und ob ein Vermerk seinen Ordner wiederfindet; im
/// schlimmsten Fall wäre ein Ordner zugeordnet **und** „ohne Mandantenbezug".
/// Dieselbe Regel gilt im Backend: `OrdnerStatusRegister` vergleicht
/// `OrdinalIgnoreCase`, die Spalte trägt die Kollation `NOCASE`.
class OrdnernamenMenge extends Equatable {
  final Set<String> _kleingeschrieben;

  OrdnernamenMenge(Iterable<String> ordnernamen)
    : _kleingeschrieben = {
        for (final name in ordnernamen) name.trim().toLowerCase(),
      };

  /// Ob [ordnername] in der Menge steht — gleich, wie er geschrieben ist.
  bool enthaelt(String ordnername) =>
      _kleingeschrieben.contains(ordnername.trim().toLowerCase());

  int get length => _kleingeschrieben.length;

  bool get isEmpty => _kleingeschrieben.isEmpty;

  bool get isNotEmpty => _kleingeschrieben.isNotEmpty;

  @override
  List<Object?> get props => [_kleingeschrieben];
}
