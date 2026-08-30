import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:equatable/equatable.dart';

/// Zeitfenster für „zuletzt geändert". Abgeschlossene Altakten gehören nicht in
/// den Zuordnungsstapel, sollen aber auch nicht verschwinden — deshalb ein
/// Filter mit [alle] als Vorgabe und nicht eine feste Grenze.
enum GeaendertSeit {
  alle('Alle', null),
  zwoelfMonate('Letzte 12 Monate', Duration(days: 365)),
  vierundzwanzigMonate('Letzte 24 Monate', Duration(days: 730)),
  fuenfJahre('Letzte 5 Jahre', Duration(days: 1826));

  const GeaendertSeit(this.bezeichnung, this.spanne);

  /// Anzeigename für die Filterleiste.
  final String bezeichnung;

  /// Wie weit zurück Ordner noch gezeigt werden. `null` = ohne Grenze.
  final Duration? spanne;
}

/// In welchen der drei Töpfe ein noch nicht zugeordneter Ordner fällt. Jeder
/// Ordner liegt in genau einem — die Ansicht ist damit eine echte Aufteilung
/// des Arbeitsvorrats und kein Ausblenden.
enum OrdnerAnsicht {
  /// Kommt als Verkehrsunfallsache in Frage: zuzuordnen. Der Arbeitsvorrat.
  stapel('Verkehrsunfall'),

  /// Nach dem Aktentyp-Präfix eine Bußgeld-, Straf- oder Familiensache — muss
  /// gar nicht zugeordnet werden, ist aber noch nicht entschieden.
  andere('Andere Ordner'),

  /// Entschieden: gehört keinem Mandanten. Jederzeit zurücknehmbar.
  ohneBezug('Ohne Mandantenbezug');

  const OrdnerAnsicht(this.bezeichnung);

  final String bezeichnung;
}

/// Was vom Zuordnungsstapel gerade zu sehen ist. Drei unabhängige Achsen:
/// Ordnername, Topf und Änderungszeitpunkt.
///
/// [ansicht] steht standardmäßig auf [OrdnerAnsicht.stapel]: im
/// Produktivbestand liegen rund 4000 Ordner unter dem Stammordner, und
/// Bußgeld-, Straf- und Familiensachen müssen keinem Mandanten zugeordnet
/// werden. Es wird dabei nichts gelöscht und nichts endgültig versteckt — die
/// anderen Töpfe stehen mit ihrer Zahl daneben und sind einen Klick entfernt.
class ZuordnungFilter extends Equatable {
  /// Freitext auf dem Ordnernamen (ohne Rücksicht auf Groß-/Kleinschreibung).
  final String query;

  /// Welcher der drei Töpfe gezeigt wird.
  final OrdnerAnsicht ansicht;

  /// Zeitfenster auf `Akte.geaendertAm`.
  final GeaendertSeit geaendertSeit;

  const ZuordnungFilter({
    this.query = '',
    this.ansicht = OrdnerAnsicht.stapel,
    this.geaendertSeit = GeaendertSeit.alle,
  });

  ZuordnungFilter copyWith({
    String? query,
    OrdnerAnsicht? ansicht,
    GeaendertSeit? geaendertSeit,
  }) => ZuordnungFilter(
    query: query ?? this.query,
    ansicht: ansicht ?? this.ansicht,
    geaendertSeit: geaendertSeit ?? this.geaendertSeit,
  );

  /// In welchen Topf [akte] gehört. Ein gesetzter Vermerk sticht den Aktentyp:
  /// die ausdrückliche Entscheidung des Anwalts geht vor der Heuristik.
  static OrdnerAnsicht ansichtVon(
    Akte akte,
    OrdnernamenMenge ohneMandantenbezug,
  ) {
    if (ohneMandantenbezug.enthaelt(akte.ordnername)) {
      return OrdnerAnsicht.ohneBezug;
    }
    return akte.aktentyp.istUnfallkandidat
        ? OrdnerAnsicht.stapel
        : OrdnerAnsicht.andere;
  }

  /// Die sichtbaren Ordner. [jetzt] ist Parameter statt `DateTime.now()`, damit
  /// der Zeitfilter prüfbar bleibt.
  List<Akte> anwenden(
    List<Akte> akten, {
    OrdnernamenMenge? ohneMandantenbezug,
    DateTime? jetzt,
  }) {
    final vermerkt = ohneMandantenbezug ?? OrdnernamenMenge(const []);
    final stichtag = _stichtag(jetzt ?? DateTime.now());
    return [
      for (final akte in akten)
        if (_passtBasis(akte, stichtag) &&
            ansichtVon(akte, vermerkt) == ansicht)
          akte,
    ];
  }

  /// Wie viele Ordner in jedem Topf liegen — die Zahlen im Umschalter. Name und
  /// Zeitfenster gelten dafür weiter, sonst sprängen sie beim Tippen nicht mit;
  /// die Töpfe selbst zählen unabhängig von [ansicht].
  Map<OrdnerAnsicht, int> zaehlen(
    List<Akte> akten, {
    OrdnernamenMenge? ohneMandantenbezug,
    DateTime? jetzt,
  }) {
    final vermerkt = ohneMandantenbezug ?? OrdnernamenMenge(const []);
    final stichtag = _stichtag(jetzt ?? DateTime.now());
    final zaehler = {for (final topf in OrdnerAnsicht.values) topf: 0};
    for (final akte in akten) {
      if (!_passtBasis(akte, stichtag)) continue;
      final topf = ansichtVon(akte, vermerkt);
      zaehler[topf] = zaehler[topf]! + 1;
    }
    return zaehler;
  }

  DateTime? _stichtag(DateTime jetzt) {
    final spanne = geaendertSeit.spanne;
    return spanne == null ? null : jetzt.subtract(spanne);
  }

  /// Name und Zeitfenster — die beiden Achsen, die für alle Zählungen gelten.
  bool _passtBasis(Akte akte, DateTime? stichtag) =>
      _passtName(akte) && _passtZeit(akte, stichtag);

  bool _passtName(Akte akte) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || akte.ordnername.toLowerCase().contains(q);
  }

  /// Ohne bekannten Änderungszeitpunkt bleibt der Ordner sichtbar: ein nicht
  /// lesbares `stat` ist kein Grund, Arbeit aus dem Stapel zu nehmen.
  bool _passtZeit(Akte akte, DateTime? stichtag) {
    if (stichtag == null) return true;
    final geaendert = akte.geaendertAm;
    return geaendert == null || !geaendert.isBefore(stichtag);
  }

  @override
  List<Object?> get props => [query, ansicht, geaendertSeit];
}
