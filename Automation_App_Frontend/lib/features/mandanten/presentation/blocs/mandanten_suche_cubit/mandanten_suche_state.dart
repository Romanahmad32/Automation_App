part of 'mandanten_suche_cubit.dart';

/// Der Stand einer Mandantensuche im Zuordnen-Dialog.
class MandantenSucheState extends Equatable {
  /// Die gezeigten Treffer — höchstens [MandantenSucheCubit.hoechstens].
  final List<Mandant> treffer;

  /// Wie viele Mandanten der Begriff insgesamt trifft. Größer als
  /// `treffer.length` heißt: verfeinern, nicht scrollen.
  final int gefunden;

  final String query;

  final bool laedt;

  final String? fehler;

  const MandantenSucheState({
    this.treffer = const [],
    this.gefunden = 0,
    this.query = '',
    this.laedt = false,
    this.fehler,
  });

  /// Ob es mehr Treffer gibt, als der Dialog zeigt.
  bool get gekuerzt => gefunden > treffer.length;

  MandantenSucheState copyWith({
    List<Mandant>? treffer,
    int? gefunden,
    String? query,
    bool? laedt,
    String? fehler,
    bool fehlerVerwerfen = false,
  }) => MandantenSucheState(
    treffer: treffer ?? this.treffer,
    gefunden: gefunden ?? this.gefunden,
    query: query ?? this.query,
    laedt: laedt ?? this.laedt,
    fehler: fehlerVerwerfen ? null : (fehler ?? this.fehler),
  );

  @override
  List<Object?> get props => [treffer, gefunden, query, laedt, fehler];
}
