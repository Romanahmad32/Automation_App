/// Kennzeichen **mit** Trennzeichen zwischen Unterscheidungszeichen und
/// Erkennungsbuchstaben — die eindeutige Schreibweise (`HG-E 1427`, `HG E1427`,
/// `hg-e 1427`). Der Trenner vor der Nummer bleibt frei, dazu optional das
/// E/H-Suffix für Elektro- und Oldtimerkennzeichen.
final _mitTrenner = RegExp(
  r'^([A-ZÄÖÜ]{1,3})[ \-]([A-ZÄÖÜ]{1,2})[ \-]?(\d{1,4})\s*([HE])?$',
);

/// Kennzeichen **ohne** Trennzeichen zwischen den Buchstabengruppen: alle
/// Buchstaben in einem Block (`HGE1427`, `HGE 1427`). Wo dieser Block
/// aufzuteilen ist, sagt das Muster nicht — das rechnet
/// [kennzeichenLesarten] aus, und oft gibt es mehr als eine Antwort.
final _ohneTrenner = RegExp(r'^([A-ZÄÖÜ]{2,5})[ \-]?(\d{1,4})\s*([HE])?$');

final _mehrfachLeerraum = RegExp(r'\s+');

/// Der **Anfang** eines Kennzeichens: die Vereinigung aller Vorsilben von
/// [_mitTrenner] und [_ohneTrenner] — der Buchstabenblock im Werden, der
/// gesetzte Trenner, die zweite Buchstabengruppe, die begonnene Nummer.
/// Wozu, steht bei [beginntWieKennzeichen].
final _kennzeichenAnfang = RegExp(
  r'^(?:[A-ZÄÖÜ]{1,5}'
  r'|[A-ZÄÖÜ]{1,3}-'
  r'|[A-ZÄÖÜ]{1,3}[ \-][A-ZÄÖÜ]{1,2}[ \-]?\d{0,4} ?[HE]?'
  r'|[A-ZÄÖÜ]{2,5}[ \-]?\d{0,4} ?[HE]?)$',
);

/// **Alle** gültigen Lesarten eines Kfz-Kennzeichens in der Domänen-Konvention
/// „Unterscheidungszeichen-Erkennungsbuchstaben Nummer" — leer, wenn sich
/// [wert] gar nicht als Kennzeichen lesen lässt.
///
/// Trägt die Eingabe ein Trennzeichen zwischen den beiden Buchstabengruppen
/// (`HG-E 1427`, `HG E1427`), ist die Aufteilung gesagt: genau eine Lesart.
/// Ohne Trennzeichen steht sie nicht fest, denn beide Gruppen sind variabel
/// lang (1–3 bzw. 1–2 Buchstaben):
///
/// | Eingabe    | Lesarten                       |
/// |------------|--------------------------------|
/// | `HE1427`   | `H-E 1427`                     |
/// | `HGE1427`  | `HG-E 1427`, `H-GE 1427`       |
/// | `FABC12`   | `FAB-C 12`, `FA-BC 12`         |
/// | `ABCDE123` | `ABC-DE 123`                   |
///
/// Die Reihenfolge ist „langes Unterscheidungszeichen zuerst" — die häufigere
/// Lesart steht vorn, wenn die Meldung sie aufzählt.
List<String> kennzeichenLesarten(String? wert) {
  if (wert == null || wert.trim().isEmpty) return const [];
  final bereinigt = wert
      .replaceAll(_mehrfachLeerraum, ' ')
      .trim()
      .toUpperCase();

  final eindeutig = _mitTrenner.firstMatch(bereinigt);
  if (eindeutig != null) {
    final suffix = eindeutig.group(4) ?? '';
    return [
      '${eindeutig.group(1)}-${eindeutig.group(2)} '
          '${eindeutig.group(3)}$suffix',
    ];
  }

  final zusammen = _ohneTrenner.firstMatch(bereinigt);
  if (zusammen == null) return const [];

  final buchstaben = zusammen.group(1)!;
  final nummer = '${zusammen.group(2)}${zusammen.group(3) ?? ''}';
  // Vorn 1–3 Buchstaben, hinten 1–2 — beides zugleich erfüllbar nur in diesem
  // Fenster; bei 2 und bei 5 Buchstaben schrumpft es auf einen einzigen Wert.
  final laengstesVorn = buchstaben.length - 1 < 3 ? buchstaben.length - 1 : 3;
  final kuerzestesVorn = buchstaben.length - 2 > 1 ? buchstaben.length - 2 : 1;
  return [
    for (var vorn = laengstesVorn; vorn >= kuerzestesVorn; vorn--)
      '${buchstaben.substring(0, vorn)}-${buchstaben.substring(vorn)} $nummer',
  ];
}

/// Überführt ein Kfz-Kennzeichen in die Domänen-Konvention
/// „Unterscheidungszeichen-Erkennungsbuchstaben Nummer" (z. B. „HG-E 1427") —
/// **aber nur, wenn die Aufteilung eindeutig ist.**
///
/// **Nur zum Vergleichen** ([gleichesKennzeichen]). Seit dem 11.09.2026 schreibt
/// die App keinen eingegebenen Wert mehr damit um (§4.2): Was im Feld steht,
/// geht so in Referenz, Vorgang und Schreiben.
///
/// Gibt es mehrere [kennzeichenLesarten] (`HGE1427` → `HG-E 1427` oder
/// `H-GE 1427`), bleibt der Wert bereinigt stehen, statt dass eine davon
/// geraten wird. Ein falsch aufgeteiltes Kennzeichen benennt ein **anderes
/// Fahrzeug** — geriete das in einen Vergleich, hielte die App zwei Wagen für
/// einen.
///
/// Spiegelt `ZentralrufReplyParser.NormalizeKennzeichen` im Backend, damit
/// Vergleiche (z. B. Fallback-Zuordnung einer Antwort über das
/// Gegner-Kennzeichen) tolerant gegenüber Schreibvarianten sind.
/// Nicht erkennbare Schreibweisen bleiben (bereinigt) unverändert.
String? normalizeKennzeichen(String? kennzeichen) {
  if (kennzeichen == null || kennzeichen.trim().isEmpty) return kennzeichen;

  final bereinigt = kennzeichen.replaceAll(_mehrfachLeerraum, ' ').trim();
  final lesarten = kennzeichenLesarten(bereinigt);
  return lesarten.length == 1 ? lesarten.single : bereinigt;
}

/// True, wenn beide Kennzeichen vorhanden sind und dasselbe Fahrzeug benennen.
///
/// **Wiedererkennen darf großzügiger sein als Anmerken.** Erfasst wird jeder
/// Wert: Ein mehrdeutiger bleibt stehen, wie er getippt wurde, und bekommt
/// unter dem Feld einen Hinweis (`KennzeichenField.beanstandung`) —
/// zurückgewiesen wird nichts (#130).
/// Beim Vergleich zweier Werte reicht es, dass ihre Lesarten sich treffen:
/// `HGE1427` und `HG-E 1427` sind derselbe Wagen, sobald eine Seite die
/// Aufteilung sagt. Die Gefahr ist hier auch die andere — wer nicht
/// wiedererkennt, bietet denselben Wagen zweimal an oder ordnet eine
/// Zentralruf-Antwort keinem Vorgang zu.
bool gleichesKennzeichen(String? a, String? b) {
  final na = normalizeKennzeichen(a);
  final nb = normalizeKennzeichen(b);
  if (na == null || na.isEmpty || nb == null || nb.isEmpty) return false;
  if (na == nb) return true;

  // Zwei Buchstabenblöcke liefern nur dann eine gemeinsame Lesart, wenn sie
  // Zeichen für Zeichen derselbe Block sind — die Schnittmenge ist also kein
  // „ähnlich", sondern „dasselbe Kennzeichen, anders geschrieben".
  final lesartenA = kennzeichenLesarten(a).toSet();
  return lesartenA.intersection(kennzeichenLesarten(b).toSet()).isNotEmpty;
}

/// Ob [wert] der **Anfang** eines Kfz-Kennzeichens sein kann — ob sich durch
/// Weitertippen also noch eine Lesart ergeben könnte.
///
/// Gebraucht wird das für die Anmerkung unter dem Feld. Sie hört auf den
/// **Wert** und nicht auf `touched`, damit ein vorbelegtes Kennzeichen nicht
/// stumm bleibt (#130) — dieselbe Frage steht damit aber auch nach jedem
/// Tastendruck an, und `H`, `HG`, `HG-`, `HG-E`, `HG-E 1` sind allesamt kein
/// Kennzeichen. Ohne diese Frage stünde „nicht erkannt" unter dem Feld,
/// während der Anwalt ein völlig gewöhnliches `HG-E 1427` tippt, und
/// verschwände erst beim letzten Zeichen.
///
/// Beantwortet wird sie am Muster und nicht durch Ausprobieren: Ein Wert ist
/// ein Anfang, wenn er zu einem der beiden Muster passt, sobald man das noch
/// Fehlende wegdenkt. `X-1234` ist deshalb **keiner** — hinter der Nummer
/// lässt sich keine Buchstabengruppe mehr nachschieben, und ohne die zweite
/// wird daraus nie ein Kennzeichen. Ein NATO-Kennzeichen bekommt seine
/// Anmerkung also sofort, ein halb getipptes Pkw-Kennzeichen gar keine.
bool beginntWieKennzeichen(String? wert) {
  if (wert == null) return false;
  final bereinigt = wert
      .replaceAll(_mehrfachLeerraum, ' ')
      .trim()
      .toUpperCase();
  return bereinigt.isNotEmpty && _kennzeichenAnfang.hasMatch(bereinigt);
}
