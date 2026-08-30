part of 'mandanten_overview_bloc.dart';

sealed class MandantenOverviewState extends Equatable {
  const MandantenOverviewState();

  @override
  List<Object?> get props => [];
}

final class MandantenOverviewLoading extends MandantenOverviewState {}

final class MandantenOverviewLoaded extends MandantenOverviewState {
  /// Die bisher geholten Mandanten — **nicht** der ganze Bestand: die Liste
  /// lädt je [MandantenOverviewBloc.seitenGroesse] nach. [query] ist dabei
  /// schon angewandt, die Suche läuft im Dienst über alle Felder.
  final List<Mandant> mandanten;

  /// Wie viele Mandanten das Register führt — das „M" in „N von M".
  final int gesamtMandanten;

  /// Wie viele davon die Suche trifft; ohne Suche gleich [gesamtMandanten].
  final int gefundeneMandanten;

  /// Die Namen **aller** zugeordneten Akten-Ordner. Aus [mandanten] wäre das
  /// seit dem seitenweisen Laden nicht mehr abzuleiten: ein Ordner, dessen
  /// Mandant auf einer noch nicht geholten Seite steht, stünde sonst als offen
  /// im Zuordnungsstapel und ließe sich ein zweites Mal zuordnen.
  final List<String> zugeordneteOrdnernamen;

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

  /// Die nächste Seite der Mandantenliste wird geholt.
  final bool mehrLadend;

  /// Eine einzelne Aktion ist gescheitert. Sie kostet eine Meldung über der
  /// Liste und **nicht** den geladenen Stand: eine fehlgeschlagene Massenaktion
  /// über hunderte Ordner sonst den Scan über tausende Ordner, den Filter und
  /// den Scrollstand mitzunehmen wäre die härtere Strafe als die Aktion wert
  /// ist.
  final String? fehler;

  late final OrdnernamenMenge _zugeordnet = OrdnernamenMenge(
    zugeordneteOrdnernamen,
  );

  /// Die Ordner mit gesetztem Vermerk „ohne Mandantenbezug".
  late final OrdnernamenMenge ohneMandantenbezug = OrdnernamenMenge([
    for (final eintrag in ordnerStatus) eintrag.ordnername,
  ]);

  MandantenOverviewLoaded({
    required this.mandanten,
    required this.akten,
    this.gesamtMandanten = 0,
    this.gefundeneMandanten = 0,
    this.zugeordneteOrdnernamen = const [],
    this.ordnerStatus = const [],
    this.query = '',
    this.zuordnungFilter = const ZuordnungFilter(),
    this.neuLadend = false,
    this.mehrLadend = false,
    this.fehler,
  });

  /// [fehlerVerwerfen] statt eines `null` in [fehler]: „nicht angegeben" und
  /// „ausdrücklich keiner mehr" sind zwei verschiedene Aussagen, und ein
  /// `copyWith` kann sie an einem nullbaren Wert nicht unterscheiden.
  MandantenOverviewLoaded copyWith({
    List<Mandant>? mandanten,
    int? gesamtMandanten,
    int? gefundeneMandanten,
    List<String>? zugeordneteOrdnernamen,
    List<Akte>? akten,
    List<OrdnerStatus>? ordnerStatus,
    String? query,
    ZuordnungFilter? zuordnungFilter,
    bool? neuLadend,
    bool? mehrLadend,
    String? fehler,
    bool fehlerVerwerfen = false,
  }) {
    return MandantenOverviewLoaded(
      mandanten: mandanten ?? this.mandanten,
      gesamtMandanten: gesamtMandanten ?? this.gesamtMandanten,
      gefundeneMandanten: gefundeneMandanten ?? this.gefundeneMandanten,
      zugeordneteOrdnernamen:
          zugeordneteOrdnernamen ?? this.zugeordneteOrdnernamen,
      akten: akten ?? this.akten,
      ordnerStatus: ordnerStatus ?? this.ordnerStatus,
      query: query ?? this.query,
      zuordnungFilter: zuordnungFilter ?? this.zuordnungFilter,
      neuLadend: neuLadend ?? this.neuLadend,
      mehrLadend: mehrLadend ?? this.mehrLadend,
      fehler: fehlerVerwerfen ? null : (fehler ?? this.fehler),
    );
  }

  /// Eine frisch geholte Seite übernehmen — Ausschnitt und beide Zahlen
  /// gehören zusammen, einzeln gesetzt liefe „N von M" auseinander.
  MandantenOverviewLoaded mitSeite(
    MandantenSeite seite,
    List<String> zugeordnet, {
    bool anhaengen = false,
  }) => copyWith(
    mandanten: anhaengen ? [...mandanten, ...seite.mandanten] : seite.mandanten,
    gesamtMandanten: seite.gesamt,
    gefundeneMandanten: seite.gefiltert,
    zugeordneteOrdnernamen: zugeordnet,
    neuLadend: false,
    mehrLadend: false,
  );

  /// Der Zustand nach dem Löschen eines Mandanten: Er fällt aus der Liste, die
  /// Zahlen gehen um eins zurück, und **seine Ordner werden frei**. Das letzte
  /// muss ausdrücklich geschehen, seit die Trennlinie des Zuordnungsstapels
  /// nicht mehr aus [mandanten] abgeleitet wird.
  MandantenOverviewLoaded ohneMandant(int mandantId) {
    final frei = OrdnernamenMenge([
      for (final m in mandanten)
        if (m.id == mandantId) ...m.aktenOrdnernamen,
    ]);
    return copyWith(
      mandanten: [
        for (final m in mandanten)
          if (m.id != mandantId) m,
      ],
      gesamtMandanten: gesamtMandanten - 1,
      gefundeneMandanten: gefundeneMandanten - 1,
      zugeordneteOrdnernamen: [
        for (final name in zugeordneteOrdnernamen)
          if (!frei.enthaelt(name)) name,
      ],
      fehlerVerwerfen: true,
    );
  }

  /// Der Zustand nach einer Zuordnung: Der Mandant kommt aktualisiert zurück,
  /// und der Ordner verlässt den Stapel — ohne erneuten Scan.
  MandantenOverviewLoaded mitZuordnung(
    Mandant aktualisiert,
    String ordnername,
  ) => copyWith(
    mandanten: [
      for (final m in mandanten)
        if (m.id == aktualisiert.id) aktualisiert else m,
    ],
    zugeordneteOrdnernamen: [...zugeordneteOrdnernamen, ordnername],
    fehlerVerwerfen: true,
  );

  /// Ob es noch Mandanten nachzuladen gibt. „Die letzte Seite war voll" wäre
  /// bei genau [MandantenOverviewBloc.seitenGroesse] Treffern falsch.
  bool get gibtWeitereMandanten => mandanten.length < gefundeneMandanten;

  /// Im Stammordner gefundene Ordner ohne Mandanten-Zuordnung — inklusive der
  /// als „ohne Mandantenbezug" vermerkten, die dort ihren eigenen Topf haben.
  List<Akte> get nichtZugeordneteAkten =>
      akten.where((a) => !_zugeordnet.enthaelt(a.ordnername)).toList();

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
        .where((a) => !vermerkt.enthaelt(a.ordnername))
        .length;
  }

  /// Die zu einem Mandanten gehörenden Akten (über die verknüpften Ordnernamen).
  List<Akte> aktenFuer(Mandant mandant) {
    final seine = OrdnernamenMenge(mandant.aktenOrdnernamen);
    return akten.where((a) => seine.enthaelt(a.ordnername)).toList();
  }

  /// Ob für [mandant] alle Fälle nachgeladen sind — erst dann ist eine
  /// Fallzahl mehr als eine Vermutung.
  bool faelleGeladenFuer(Mandant mandant) =>
      aktenFuer(mandant).every((a) => a.faelleGeladen);

  @override
  List<Object?> get props => [
    mandanten,
    gesamtMandanten,
    gefundeneMandanten,
    zugeordneteOrdnernamen,
    akten,
    ordnerStatus,
    query,
    zuordnungFilter,
    neuLadend,
    mehrLadend,
    fehler,
  ];
}

final class MandantenOverviewError extends MandantenOverviewState {
  final String message;

  const MandantenOverviewError(this.message);

  @override
  List<Object?> get props => [message];
}
