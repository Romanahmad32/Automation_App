part of 'mandanten_overview_bloc.dart';

sealed class MandantenOverviewState extends Equatable {
  const MandantenOverviewState();

  @override
  List<Object?> get props => [];
}

final class MandantenOverviewLoading extends MandantenOverviewState {}

final class MandantenOverviewLoaded extends MandantenOverviewState {
  /// Alle Mandanten aus dem Register (ungefiltert, Quelle der Wahrheit).
  final List<Mandant> mandanten;

  /// Alle im Stammordner gefundenen Akten — flach gescannt, die Fälle je Akte
  /// kommen über `LadeFaelleEvent` nach.
  final List<Akte> akten;

  /// Die Ordner, für die entschieden ist, dass sie keinem Mandanten gehören.
  final List<OrdnerStatus> ordnerStatus;

  /// Aktueller Suchbegriff über die Mandanten. Leer = kein Filter.
  final String query;

  /// Was vom Zuordnungsstapel zu sehen ist — eigene Achse, unabhängig von
  /// [query]: die Mandantensuche findet keine unzugeordneten Ordner.
  final ZuordnungFilter zuordnungFilter;

  /// Ein Neuladen läuft, der bisherige Stand bleibt derweil stehen. Ein
  /// Spinner statt der Liste wäre bei 4000 Ordnern ein Rückschritt: nach jeder
  /// Zuordnung verlöre man Scrollstand und Filter.
  final bool neuLadend;

  const MandantenOverviewLoaded({
    required this.mandanten,
    required this.akten,
    this.ordnerStatus = const [],
    this.query = '',
    this.zuordnungFilter = const ZuordnungFilter(),
    this.neuLadend = false,
  });

  MandantenOverviewLoaded copyWith({
    List<Mandant>? mandanten,
    List<Akte>? akten,
    List<OrdnerStatus>? ordnerStatus,
    String? query,
    ZuordnungFilter? zuordnungFilter,
    bool? neuLadend,
  }) {
    return MandantenOverviewLoaded(
      mandanten: mandanten ?? this.mandanten,
      akten: akten ?? this.akten,
      ordnerStatus: ordnerStatus ?? this.ordnerStatus,
      query: query ?? this.query,
      zuordnungFilter: zuordnungFilter ?? this.zuordnungFilter,
      neuLadend: neuLadend ?? this.neuLadend,
    );
  }

  /// Nach [query] gefilterte Mandanten (Name, Ort oder Ordnername, case-insensitive).
  List<Mandant> get gefilterteMandanten {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return mandanten;
    return mandanten.where((m) {
      if (m.anzeigename.toLowerCase().contains(q)) return true;
      if (m.ort.toLowerCase().contains(q)) return true;
      return m.aktenOrdnernamen.any((o) => o.toLowerCase().contains(q));
    }).toList();
  }

  /// Alle Ordnernamen, die irgendeinem Mandanten zugeordnet sind.
  Set<String> get _zugeordneteOrdner => {
    for (final m in mandanten) ...m.aktenOrdnernamen,
  };

  /// Die Ordner mit gesetztem Vermerk „ohne Mandantenbezug".
  Set<String> get ohneMandantenbezug => {
    for (final eintrag in ordnerStatus) eintrag.ordnername,
  };

  /// Im Stammordner gefundene Ordner ohne Mandanten-Zuordnung — inklusive der
  /// als „ohne Mandantenbezug" vermerkten, die dort ihren eigenen Topf haben.
  List<Akte> get nichtZugeordneteAkten {
    final zugeordnet = _zugeordneteOrdner;
    return akten.where((a) => !zugeordnet.contains(a.ordnername)).toList();
  }

  /// Der Arbeitsvorrat, wie ihn [zuordnungFilter] gerade zeigt.
  List<Akte> get sichtbareNichtZugeordnete => zuordnungFilter.anwenden(
    nichtZugeordneteAkten,
    ohneMandantenbezug: ohneMandantenbezug,
  );

  /// Wie viele Ordner in jedem Topf liegen — mit Suche und Zeitfenster.
  Map<OrdnerAnsicht, int> get ordnerZaehler => zuordnungFilter.zaehlen(
    nichtZugeordneteAkten,
    ohneMandantenbezug: ohneMandantenbezug,
  );

  /// Dieselben Töpfe ohne Suche und Zeitfenster — der Bezugswert für „N von M".
  /// Der Vorgabefilter greift auf keiner der beiden Achsen; welchen Topf er
  /// zeigt, spielt beim Zählen keine Rolle.
  Map<OrdnerAnsicht, int> get ordnerZaehlerUngefiltert =>
      const ZuordnungFilter().zaehlen(
        nichtZugeordneteAkten,
        ohneMandantenbezug: ohneMandantenbezug,
      );

  /// Noch zu entscheidende Ordner: weder zugeordnet noch vermerkt. Das ist die
  /// Zahl, die auf null gehen kann und darum auf der Übersicht steht.
  int get offeneOrdnerAnzahl {
    final vermerkt = ohneMandantenbezug;
    return nichtZugeordneteAkten
        .where((a) => !vermerkt.contains(a.ordnername))
        .length;
  }

  /// Die zu einem Mandanten gehörenden Akten (über die verknüpften Ordnernamen).
  List<Akte> aktenFuer(Mandant mandant) {
    return akten
        .where((a) => mandant.aktenOrdnernamen.contains(a.ordnername))
        .toList();
  }

  /// Ob für [mandant] alle Fälle nachgeladen sind — erst dann ist eine
  /// Fallzahl mehr als eine Vermutung.
  bool faelleGeladenFuer(Mandant mandant) =>
      aktenFuer(mandant).every((a) => a.faelleGeladen);

  @override
  List<Object?> get props => [
    mandanten,
    akten,
    ordnerStatus,
    query,
    zuordnungFilter,
    neuLadend,
  ];
}

final class MandantenOverviewError extends MandantenOverviewState {
  final String message;

  const MandantenOverviewError(this.message);

  @override
  List<Object?> get props => [message];
}
