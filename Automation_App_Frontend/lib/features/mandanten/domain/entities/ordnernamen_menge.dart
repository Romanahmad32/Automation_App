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

  /// [ordnernamen] ohne die, die in der Menge stehen — in ihrer Reihenfolge.
  /// Der eine Weg, Namen aus einer Liste zu nehmen: Von Hand ausgeschrieben
  /// stand dieselbe Schleife an vier Stellen, und die nächste hätte beim
  /// Vergleich vielleicht nicht getrimmt.
  List<String> ohne(Iterable<String> ordnernamen) =>
      ohneEintraege(ordnernamen, (name) => name);

  /// Wie [ohne], für Einträge, die einen Ordnernamen tragen —
  /// [ordnernameVon] liest ihn.
  List<T> ohneEintraege<T>(
    Iterable<T> eintraege,
    String Function(T eintrag) ordnernameVon,
  ) => [
    for (final eintrag in eintraege)
      if (!enthaelt(ordnernameVon(eintrag))) eintrag,
  ];

  int get length => _kleingeschrieben.length;

  bool get isEmpty => _kleingeschrieben.isEmpty;

  bool get isNotEmpty => _kleingeschrieben.isNotEmpty;

  @override
  List<Object?> get props => [_kleingeschrieben];
}
