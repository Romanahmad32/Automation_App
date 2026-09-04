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
/// Gibt es mehrere [kennzeichenLesarten] (`HGE1427` → `HG-E 1427` oder
/// `H-GE 1427`), bleibt der Wert bereinigt stehen, statt dass eine davon
/// geraten wird. Ein falsch aufgeteiltes Kennzeichen benennt ein **anderes
/// Fahrzeug**; es steht danach in der Referenz, im Registereintrag und im
/// Anspruchsschreiben, und niemand sieht ihm an, dass es geraten wurde. Eine
/// Rückfrage kostet einen Bindestrich, ein falscher Wagen einen Schriftsatz.
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
/// **Wiedererkennen darf großzügiger sein als Erfassen.** Beim Erfassen wird
/// eine mehrdeutige Eingabe zurückgewiesen ([istMehrdeutigesKennzeichen]);
/// beim Vergleich zweier Werte reicht es, dass ihre Lesarten sich treffen:
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

/// Ob [wert] **eindeutig** als Kfz-Kennzeichen lesbar ist — genau das, was
/// [normalizeKennzeichen] in die Konvention überführen kann. Leer und `null`
/// sind **kein** Kennzeichen; ob ein leeres Feld erlaubt ist, entscheidet der
/// Pflicht-Validator daneben und nicht diese Frage. Ein mehrdeutiger Wert ist
/// hier ebenfalls `false` — er ist nicht falsch, aber noch nicht entschieden
/// ([istMehrdeutigesKennzeichen] trennt die beiden Fälle für die Meldung).
bool istKennzeichen(String? wert) => kennzeichenLesarten(wert).length == 1;

/// Ob [wert] sich als Kennzeichen lesen lässt, aber auf **mehr als eine** Art
/// (`HGE1427`, `FABC12`). Das ist kein Tippfehler, sondern eine fehlende
/// Angabe: Der Bindestrich sagt, wo das Unterscheidungszeichen endet.
bool istMehrdeutigesKennzeichen(String? wert) =>
    kennzeichenLesarten(wert).length > 1;
