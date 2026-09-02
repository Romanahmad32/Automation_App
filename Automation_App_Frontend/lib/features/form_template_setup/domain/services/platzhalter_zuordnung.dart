import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';

/// Wie nah sich ein Feldname und ein Platzhalter kommen, ohne zeichengleich zu
/// sein — die beiden Fälle, für die sich ein Vorschlag lohnt (#36).
enum ZuordnungsGuete {
  /// Nach [FeldDatenquelleErkennung.normalisiere] derselbe Name, im Dokument
  /// aber ein anderer: `Versicherungsschein-Nr` gegen `{{VersicherungsscheinNr}}`.
  ///
  /// Der stille Killer: Für jeden Menschen ist das dasselbe Wort, für die
  /// Ersetzung im Backend nicht — sie kennt nur `IgnoreCase`, keinen
  /// Bindestrich und keinen Umlaut.
  schreibweise(
    'nur anders geschrieben',
    'Derselbe Name in anderer Schreibweise. Die Ersetzung im Dokument achtet '
        'auf jedes Zeichen — Bindestrich, Punkt und Umlaut zählen mit.',
  ),

  /// Der eine Name steckt im anderen: `Unfalldatum` in `Verkehrsunfalldatum`.
  teilname(
    'ähnlicher Name',
    'Der eine Name steckt im anderen. Ob dieselbe Angabe gemeint ist, '
        'entscheidet nur der Mensch.',
  );

  /// Kurztext am Vorschlag.
  final String anzeige;

  /// Satz darunter, der sagt, worauf sich der Vorschlag stützt.
  final String erklaerung;

  const ZuordnungsGuete(this.anzeige, this.erklaerung);
}

/// Ein Kandidat für die Zuordnung: der [name] der Gegenseite und wie sicher er
/// ist.
class ZuordnungsVorschlag {
  final String name;
  final ZuordnungsGuete guete;

  /// Der Kandidat trifft heute schon einen Platzhalter — ihn umzubenennen
  /// tauscht einen Waisen gegen einen anderen und heilt nichts.
  ///
  /// Genau der Produktivfall aus #36: Die HGN-Datei sagt
  /// `{{Verkehrsunfalldatum}}`, die Auflistungs-Datei `{{Unfalldatum}}`. Ein
  /// Feld kann nur einen der beiden Namen tragen; die Dateien selbst
  /// geradezuziehen ist die einzige Reparatur. Solche Kandidaten werden
  /// deshalb **nicht** zum Umbenennen angeboten, sondern als Befund gezeigt.
  final bool tauschtWaise;

  const ZuordnungsVorschlag({
    required this.name,
    required this.guete,
    this.tauschtWaise = false,
  });
}

/// Sucht zu einem Namen ohne Gegenstück den passenden Partner auf der anderen
/// Seite — für beide Richtungen dieselbe Regel (#36):
///
/// - ein **Platzhalter ohne Feld** sucht unter den Feldnamen (statt ein
///   zweites Feld anzulegen, das der Anwalt zusätzlich tippt),
/// - ein **Feld ohne Platzhalter** sucht unter den übrig gebliebenen
///   Platzhaltern.
///
/// Es bleibt ein Vorschlag: Umbenannt wird erst auf Bestätigung (§1.3
/// „Vorschlagen statt entscheiden").
class PlatzhalterZuordnung {
  const PlatzhalterZuordnung._();

  /// Ab dieser Länge (normalisiert) darf ein Name im anderen stecken und gilt
  /// als [ZuordnungsGuete.teilname]. Kürzeres träfe zu viel: `Ort` steckt in
  /// `Wohnort`, `Sortierung` und `Vorortermin`.
  static const int mindestLaenge = 5;

  /// Kandidaten für [gesucht], die besten zuerst.
  ///
  /// [belegtePlatzhalter] sind alle Platzhalter **beider** Word-Dateien. Ein
  /// Kandidat, der darin vorkommt, wird als [ZuordnungsVorschlag.tauschtWaise]
  /// markiert und ans Ende sortiert — er ist ein Befund, kein Angebot.
  ///
  /// Zeichengleiche Namen (bis auf Groß-/Kleinschreibung) fallen heraus: Die
  /// treffen sich beim Erzeugen ohnehin, da gibt es nichts vorzuschlagen.
  static List<ZuordnungsVorschlag> vorschlaege(
    String gesucht,
    Iterable<String?> kandidaten, {
    Iterable<String> belegtePlatzhalter = const [],
  }) {
    final gesuchtKlein = gesucht.trim().toLowerCase();
    final gesuchtNormal = FeldDatenquelleErkennung.normalisiere(gesucht);
    if (gesuchtNormal.isEmpty) return const [];

    final belegt = {
      for (final platzhalter in belegtePlatzhalter)
        platzhalter.trim().toLowerCase(),
    };
    final gesehen = <String>{gesuchtKlein};
    final treffer = <ZuordnungsVorschlag>[];

    for (final kandidat in kandidaten) {
      final name = kandidat?.trim();
      if (name == null || name.isEmpty) continue;
      if (!gesehen.add(name.toLowerCase())) continue;

      final guete = _guete(gesuchtNormal, name);
      if (guete == null) continue;
      treffer.add(
        ZuordnungsVorschlag(
          name: name,
          guete: guete,
          tauschtWaise: belegt.contains(name.toLowerCase()),
        ),
      );
    }

    treffer.sort((a, b) => _rang(a, gesuchtNormal) - _rang(b, gesuchtNormal));
    return treffer;
  }

  /// Wie [name] zu dem bereits normalisierten [gesuchtNormal] steht; null,
  /// wenn er zu weit weg ist.
  static ZuordnungsGuete? _guete(String gesuchtNormal, String name) {
    final normal = FeldDatenquelleErkennung.normalisiere(name);
    if (normal.isEmpty) return null;
    if (normal == gesuchtNormal) return ZuordnungsGuete.schreibweise;

    final kurz = normal.length < gesuchtNormal.length ? normal : gesuchtNormal;
    final lang = normal.length < gesuchtNormal.length ? gesuchtNormal : normal;
    if (kurz.length >= mindestLaenge && lang.contains(kurz)) {
      return ZuordnungsGuete.teilname;
    }
    return null;
  }

  /// Sortierschlüssel: erst was wirklich hilft (kein Waisen-Tausch), dann die
  /// sicherere Güte, dann der Name, der am wenigsten danebenliegt.
  static int _rang(ZuordnungsVorschlag vorschlag, String gesuchtNormal) {
    final laengenAbstand =
        (FeldDatenquelleErkennung.normalisiere(vorschlag.name).length -
                gesuchtNormal.length)
            .abs();
    return (vorschlag.tauschtWaise ? 10000 : 0) +
        vorschlag.guete.index * 1000 +
        laengenAbstand.clamp(0, 999);
  }
}
