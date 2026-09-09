import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
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
/// Die Namen sagen, **was zu tun ist**, und nicht, was erkannt wurde. Der
/// Unterschied ist in der Kanzlei aufgefallen: „Verkehrsunfall (265)" las sich
/// als Erkennungsquote, obwohl 152 dieser 265 Ordner überhaupt kein Präfix
/// tragen und nur deshalb dort liegen, weil ihr Name nichts verrät. Und
/// „Ohne Mandantenbezug (0)" stand als dritte Quote neben zwei automatisch
/// gefüllten Töpfen, obwohl diesen Topf allein der Anwalt füllt — 0 ist dort
/// der richtige Anfangswert und kein Fehlschlag.
enum OrdnerAnsicht {
  /// Kommt als Verkehrsunfallsache in Frage: zuzuordnen. Der Arbeitsvorrat —
  /// Ordner mit Verkehrsunfall-Präfix **und** solche ganz ohne Präfix.
  stapel(
    'Zuzuordnen',
    'Verkehrsunfallsachen und Ordner, deren Name keinen '
        'Aktentyp nennt — hier liegt die Arbeit.',
  ),

  /// Nach dem Aktentyp-Präfix eine Bußgeld-, Straf- oder Familiensache — muss
  /// gar nicht zugeordnet werden, ist aber noch nicht entschieden.
  andere(
    'Andere Sachgebiete',
    'Bußgeld-, Straf- und Familiensachen laut '
        'Präfix im Ordnernamen — diese App ordnet sie nicht zu.',
  ),

  /// Entschieden: gehört keinem Mandanten. Jederzeit zurücknehmbar.
  ohneBezug(
    'Beiseitegelegt',
    'Von Hand als „ohne Mandantenbezug" vermerkt. '
        'Nichts wird hier automatisch einsortiert; jederzeit zurückzunehmen.',
  );

  const OrdnerAnsicht(this.bezeichnung, this.erklaerung);

  final String bezeichnung;

  /// Was in diesem Topf liegt und wie es dorthin kommt — als Tooltip am
  /// Umschalter.
  final String erklaerung;
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

  /// Woher die Ordner im Topf [OrdnerAnsicht.stapel] stammen: aus dem
  /// erkannten Verkehrsunfall-Präfix oder daraus, dass der Name **keinen**
  /// Aktentyp nennt. Beides landet im selben Topf (`istUnfallkandidat`), und
  /// solange die Oberfläche das nicht auseinanderhält, liest sich die Zahl als
  /// Erkennungsquote — im Bestand der Kanzlei hat die knappe Mehrheit gar kein
  /// Präfix.
  ({int mitPraefix, int ohnePraefix}) herkunftImStapel(
    List<Akte> akten, {
    OrdnernamenMenge? ohneMandantenbezug,
    DateTime? jetzt,
  }) {
    final vermerkt = ohneMandantenbezug ?? OrdnernamenMenge(const []);
    final stichtag = _stichtag(jetzt ?? DateTime.now());
    var mitPraefix = 0;
    var ohnePraefix = 0;
    for (final akte in akten) {
      if (!_passtBasis(akte, stichtag)) continue;
      if (ansichtVon(akte, vermerkt) != OrdnerAnsicht.stapel) continue;
      if (akte.aktentyp == Aktentyp.ohnePraefix) {
        ohnePraefix++;
      } else {
        mitPraefix++;
      }
    }
    return (mitPraefix: mitPraefix, ohnePraefix: ohnePraefix);
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
