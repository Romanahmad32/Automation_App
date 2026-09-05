part of 'arbeitspaket_cubit.dart';

/// Der Stand der Paket-Buchführung: die Historie, ob gerade etwas läuft, und
/// der letzte Fehler.
///
/// Wie beim Import ein Zustand mit Merkmalen statt einer Kette von
/// Zustandsklassen: Die Historie bleibt stehen, auch während das nächste Paket
/// geholt wird. Ein eigener „lädt"-Zustand müsste sie mitführen — oder die
/// Tabelle verschwände für einen Augenblick, obwohl sich an ihr nichts ändert.
class ArbeitspaketState extends Equatable {
  /// Die herausgegebenen Pakete, neuestes zuerst (so liefert sie der Dienst).
  final List<Arbeitspaket> historie;

  final bool laufend;
  final String? fehler;

  /// Der letzte Versuch, ein Paket zu holen, fand keinen offenen Ordner mehr
  /// (Dienst: 409).
  ///
  /// Bewusst **kein** Eintrag in [fehler]: Das ist der Abschluss des Vorgangs,
  /// nicht seine Störung. Der Zuordnungsstapel ist leer, und eine rote Meldung
  /// dafür würde dem Anwalt einen Defekt melden, wo er fertig ist.
  final bool nichtsOffen;

  const ArbeitspaketState({
    this.historie = const [],
    this.laufend = false,
    this.fehler,
    this.nichtsOffen = false,
  });

  /// Das zuletzt herausgegebene Paket — die Zeile, auf die der Anwalt zuerst
  /// sieht. Null, solange noch keines geholt wurde.
  Arbeitspaket? get neuestes => historie.isEmpty ? null : historie.first;

  /// Pakete, deren Antwortdatei noch nicht eingelesen wurde. Daran fällt auf,
  /// dass Paket 3 fehlt, bevor Paket 4 geholt wird.
  int get offeneAnzahl => historie.where((p) => !p.eingelesen).length;

  /// Nicht übergebene Felder bleiben stehen. [fehler] muss sich auch wieder
  /// leeren lassen — dafür der Schalter, weil `null` hier „unverändert" heißt.
  ArbeitspaketState copyWith({
    List<Arbeitspaket>? historie,
    bool? laufend,
    String? fehler,
    bool? nichtsOffen,
    bool fehlerLoeschen = false,
  }) => ArbeitspaketState(
    historie: historie ?? this.historie,
    laufend: laufend ?? this.laufend,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
    nichtsOffen: nichtsOffen ?? this.nichtsOffen,
  );

  @override
  List<Object?> get props => [historie, laufend, fehler, nichtsOffen];
}
