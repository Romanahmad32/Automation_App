import 'package:equatable/equatable.dart';

/// Was der Import mit einer Zeile macht.
enum ImportArt {
  neu('neu', 'Neu'),
  ergaenzt('ergaenzt', 'Ergänzt'),
  unveraendert('unveraendert', 'Unverändert'),
  abgelehnt('abgelehnt', 'Abgelehnt');

  final String wert;
  final String bezeichnung;

  const ImportArt(this.wert, this.bezeichnung);

  /// Unbekannte Werte fallen auf [unveraendert]: eine Oberfläche, die die
  /// Handlung nicht benennen kann, darf auch keine behaupten. Die Zahlen der
  /// Zusammenfassung kommen unabhängig davon vom Dienst und bleiben richtig.
  static ImportArt ausWert(String? wert) {
    for (final art in ImportArt.values) {
      if (art.wert == wert) return art;
    }
    return unveraendert;
  }
}

/// Wie sicher sich der Erzeuger der Datei bei dieser Zeile war.
enum ImportSicherheit {
  hoch('hoch', 'sicher'),
  mittel('mittel', 'unsicher'),
  niedrig('niedrig', 'sehr unsicher'),
  unbekannt('', 'ohne Angabe');

  final String wert;
  final String bezeichnung;

  const ImportSicherheit(this.wert, this.bezeichnung);

  /// Alles, was nicht ausdrücklich `hoch` sagt, gilt als prüfenswert — deshalb
  /// ist [unbekannt] der Rückfall und nicht [hoch].
  static ImportSicherheit ausWert(String? wert) {
    final normal = (wert ?? '').trim().toLowerCase();
    for (final stufe in ImportSicherheit.values) {
      if (stufe.wert == normal) return stufe;
    }
    return unbekannt;
  }
}

/// Was ein Import bewirkt hat oder bewirken würde. Vorschau und Übernahme
/// liefern denselben Bericht; nur [angewendet] unterscheidet sie — die Vorschau
/// zeigt damit garantiert das, was die Übernahme tut.
class ImportBericht extends Equatable {
  final List<ImportEintrag> eintraege;
  final int neu;
  final int ergaenzt;
  final int unveraendert;
  final int abgelehnt;

  /// Akten-Ordner, die dadurch an einen Mandanten gehen — die Zahl, um die der
  /// Zuordnungsstapel kleiner wird.
  final int ordnerZugeordnet;

  /// Ordner, die als „ohne Mandantenbezug" vermerkt werden.
  final int ohneMandantenbezug;

  final bool angewendet;

  const ImportBericht({
    this.eintraege = const [],
    this.neu = 0,
    this.ergaenzt = 0,
    this.unveraendert = 0,
    this.abgelehnt = 0,
    this.ordnerZugeordnet = 0,
    this.ohneMandantenbezug = 0,
    this.angewendet = false,
  });

  /// Zeilen, die etwas zu sagen haben: abgelehnt oder mit einem Hinweis. Sie
  /// sind der Teil, den ein Mensch wirklich ansehen muss.
  int get zuPruefen => eintraege
      .where((e) => e.art == ImportArt.abgelehnt || e.hinweise.isNotEmpty)
      .length;

  /// Ändert der Import überhaupt etwas? Sonst wäre „Übernehmen" ein Knopf ohne
  /// Wirkung.
  bool get bewirktEtwas =>
      neu > 0 || ergaenzt > 0 || ordnerZugeordnet > 0 || ohneMandantenbezug > 0;

  factory ImportBericht.fromJson(Map<String, dynamic> json) {
    final eintraege = json['eintraege'];
    return ImportBericht(
      eintraege: eintraege is List
          ? [
              for (final eintrag in eintraege.whereType<Map<String, dynamic>>())
                ImportEintrag.fromJson(eintrag),
            ]
          : const [],
      neu: json['neu'] as int? ?? 0,
      ergaenzt: json['ergaenzt'] as int? ?? 0,
      unveraendert: json['unveraendert'] as int? ?? 0,
      abgelehnt: json['abgelehnt'] as int? ?? 0,
      ordnerZugeordnet: json['ordnerZugeordnet'] as int? ?? 0,
      ohneMandantenbezug: json['ohneMandantenbezug'] as int? ?? 0,
      angewendet: json['angewendet'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    eintraege,
    neu,
    ergaenzt,
    unveraendert,
    abgelehnt,
    ordnerZugeordnet,
    ohneMandantenbezug,
    angewendet,
  ];
}

/// Das Ergebnis einer einzelnen Zeile der Importdatei.
class ImportEintrag extends Equatable {
  /// Position in `mandanten` ab 0 — der Bezug zurück in die Datei.
  final int zeile;

  final String anzeigename;

  /// Die Ordner, die dieser Mandant durch den Import wirklich bekommt. Was
  /// schon einem anderen gehört, steht nicht hier, sondern in [hinweise].
  final List<String> aktenOrdnernamen;

  final ImportArt art;
  final int? mandantId;
  final ImportSicherheit sicherheit;
  final String quelle;

  /// Alles, was an dieser Zeile nicht glatt durchging — jeweils im Klartext.
  final List<String> hinweise;

  const ImportEintrag({
    required this.zeile,
    this.anzeigename = '',
    this.aktenOrdnernamen = const [],
    this.art = ImportArt.unveraendert,
    this.mandantId,
    this.sicherheit = ImportSicherheit.unbekannt,
    this.quelle = '',
    this.hinweise = const [],
  });

  bool get istAuffaellig => art == ImportArt.abgelehnt || hinweise.isNotEmpty;

  factory ImportEintrag.fromJson(Map<String, dynamic> json) {
    final ordner = json['aktenOrdnernamen'];
    final hinweise = json['hinweise'];
    return ImportEintrag(
      zeile: json['zeile'] as int? ?? 0,
      anzeigename: json['anzeigename'] as String? ?? '',
      aktenOrdnernamen: ordner is List
          ? ordner.whereType<String>().toList()
          : const [],
      art: ImportArt.ausWert(json['art'] as String?),
      mandantId: json['mandantId'] as int?,
      sicherheit: ImportSicherheit.ausWert(json['sicherheit'] as String?),
      quelle: json['quelle'] as String? ?? '',
      hinweise: hinweise is List
          ? hinweise.whereType<String>().toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [
    zeile,
    anzeigename,
    aktenOrdnernamen,
    art,
    mandantId,
    sicherheit,
    quelle,
    hinweise,
  ];
}
