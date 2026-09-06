/// Der Name, unter dem eine duplizierte Vorlage angelegt wird (#104 Stufe 4).
///
/// Die Namenseindeutigkeit erzwingt das Backend (409, `FormTemplateRepository
/// .EnsureNameUniqueAsync`). Dieser Vorschlag soll dafür sorgen, dass der
/// Anwalt diesen Fehler gar nicht erst zu sehen bekommt — er ist die
/// Bequemlichkeit, nicht die Sicherung: Wer zwischendurch in einem zweiten
/// Fenster dieselbe Vorlage angelegt hat, bekommt weiterhin die Meldung des
/// Dienstes.
class KopieName {
  const KopieName._();

  /// Das Wort, das eine Kopie kenntlich macht.
  static const String wort = 'Kopie';

  /// Der Vorschlag für eine Kopie von [original], der mit keinem Namen in
  /// [vorhandene] zusammenfällt: `… (Kopie)`, sonst `… (Kopie 2)`,
  /// `… (Kopie 3)` …
  ///
  /// **Verglichen wird ohne Groß-/Kleinschreibung und ohne Randleerzeichen.**
  /// Das ist strenger als das Backend (SQLite vergleicht `TemplateName`
  /// binär), und zwar mit Absicht: Zwei Vorlagen, die sich nur in der
  /// Schreibweise unterscheiden, sind für den Anwalt dieselbe.
  ///
  /// Heißt [original] selbst schon `… (Kopie)` oder `… (Kopie 7)`, wird am
  /// **Stamm** weitergezählt statt ein zweites `(Kopie)` angehängt: Sonst
  /// wüchse mit jedem Klick ein Wortstapel, in dem die Vorlage nicht mehr zu
  /// erkennen ist.
  static String fuer(String original, Iterable<String> vorhandene) {
    final belegt = {for (final name in vorhandene) name.trim().toLowerCase()};
    final stamm = _stamm(original.trim());

    var vorschlag = '$stamm ($wort)';
    var zaehler = 1;
    while (belegt.contains(vorschlag.toLowerCase())) {
      zaehler++;
      vorschlag = '$stamm ($wort $zaehler)';
    }
    return vorschlag;
  }

  /// [name] ohne ein abschließendes `(Kopie)` / `(Kopie N)`. Nur **ein**
  /// Anhängsel wird abgeschnitten: `Brief (Kopie) (Kopie 2)` ist ein Name, den
  /// diese Klasse nie erzeugt hat, und Namen zu zerlegen, die jemand von Hand
  /// vergeben hat, hieße raten.
  static String _stamm(String name) {
    final treffer = RegExp(
      r'^(.*?)\s*\(' + wort + r'(?:\s+\d+)?\)$',
      caseSensitive: false,
    ).firstMatch(name);
    if (treffer == null) return name;
    final stamm = treffer.group(1)!.trim();
    // `(Kopie)` ganz allein ist kein Anhängsel, sondern der ganze Name — ihn
    // abzuschneiden liesse nichts übrig.
    return stamm.isEmpty ? name : stamm;
  }
}
