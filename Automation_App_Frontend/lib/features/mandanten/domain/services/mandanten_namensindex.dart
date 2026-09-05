import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';

/// Billiger Vorfilter vor [MandantErkennung]: grenzt den Bestand auf die
/// wenigen Mandanten ein, die überhaupt in Frage kommen.
///
/// Der Anlass ist die Größenordnung des Imports: eine Vorschau hat bis zu 200
/// Zeilen, das Register mehrere tausend Einträge. Jede Zeile gegen jeden
/// Eintrag zu rechnen wären Millionen Damerau-Levenshtein-Durchläufe — einmal
/// beim Öffnen und noch einmal nach **jeder** berichtigten Zeile.
///
/// **Der Filter darf nichts ausschließen, was [MandantErkennung] gefunden
/// hätte.** Er ist deshalb bewusst großzügig und bildet die drei Regeln von
/// dort einzeln ab:
///
/// * *Gleichheit* und *ein Tippfehler* (auch ein Buchstabendreher) über den
///   **Löschindex**: zwei Namen mit Abstand ≤ 1 haben immer eine gemeinsame
///   Löschvariante — beim Ersetzen fällt an derselben Stelle beidseits dasselbe
///   Wort heraus, beim Einfügen/Löschen ist der kürzere selbst die Variante des
///   längeren, und beim Dreher trifft sich „xy" mit „yx" bei je einer Löschung.
///   Ein Eimer über die ersten Buchstaben leistete das **nicht**: „Bauer" und
///   „Auer" liegen einen Tippfehler auseinander und begännen verschieden.
/// * *Tippbeginn* über die ersten [MandantErkennung.minPraefixLaenge] Zeichen:
///   ist einer der beiden Namen der Anfang des anderen, stimmen sie dort
///   überein.
/// * Nachnamen, die **kürzer** als diese Schranke sind, kommen immer mit — sie
///   können Anfang eines längeren sein, ohne einen eigenen Eimer zu füllen. Es
///   sind wenige.
///
/// Dazu die Kennzeichen: das stärkste Signal von [MandantErkennung] hängt gar
/// nicht am Namen, und ein Filter, der nur Namen kennt, nähme es ihr weg.
///
/// Normalisiert wird über [MandantErkennung.normalisiereName] bzw.
/// [MandantErkennung.normalisiereKennzeichen] — dieselbe Schreibweise wie beim
/// Vergleich selbst. Eine zweite Normalisierung hier wäre genau die Art
/// Abweichung, die still Treffer verschluckt.
class MandantenNamensindex {
  /// Erste [MandantErkennung.minPraefixLaenge] Zeichen → Mandanten.
  final Map<String, List<Mandant>> _nachAnfang = {};

  /// Löschvariante → Mandanten.
  final Map<String, List<Mandant>> _nachLoeschung = {};

  /// Normalisiertes Kennzeichen → Mandanten.
  final Map<String, List<Mandant>> _nachKennzeichen = {};

  /// Mandanten mit sehr kurzem Nachnamen — immer Kandidat.
  final List<Mandant> _kurzeNachnamen = [];

  MandantenNamensindex(List<Mandant> mandanten) {
    for (final mandant in mandanten) {
      _lege(mandant);
    }
  }

  /// Die Mandanten, gegen die sich ein Vergleich lohnt. Reihenfolge wie im
  /// übergebenen Bestand, jeder höchstens einmal.
  List<Mandant> kandidaten({
    required String nachname,
    List<String> kennzeichen = const [],
  }) {
    final gefunden = <int, Mandant>{};
    final name = MandantErkennung.normalisiereName(nachname);

    if (name.isNotEmpty) {
      if (name.length >= MandantErkennung.minPraefixLaenge) {
        _sammle(gefunden, _nachAnfang[_anfang(name)]);
      }
      for (final schluessel in loeschvarianten(name)) {
        _sammle(gefunden, _nachLoeschung[schluessel]);
      }
      _sammle(gefunden, _kurzeNachnamen);
    }

    for (final zeichen in kennzeichen) {
      final wert = MandantErkennung.normalisiereKennzeichen(zeichen);
      if (wert.isNotEmpty) _sammle(gefunden, _nachKennzeichen[wert]);
    }

    return gefunden.values.toList();
  }

  /// Der Name selbst und jede Fassung mit genau einem gelöschten Zeichen.
  /// Leere Schlüssel bleiben draußen: sie träfen jeden Einbuchstaben-Namen und
  /// nur den — die stehen ohnehin in [_kurzeNachnamen].
  static Set<String> loeschvarianten(String name) {
    final varianten = <String>{if (name.isNotEmpty) name};
    if (name.length < 2) return varianten;
    for (var i = 0; i < name.length; i++) {
      varianten.add(name.substring(0, i) + name.substring(i + 1));
    }
    return varianten;
  }

  void _lege(Mandant mandant) {
    final name = MandantErkennung.normalisiereName(mandant.nachname);
    if (name.isNotEmpty) {
      if (name.length >= MandantErkennung.minPraefixLaenge) {
        _eintragen(_nachAnfang, _anfang(name), mandant);
      } else {
        _kurzeNachnamen.add(mandant);
      }
      for (final schluessel in loeschvarianten(name)) {
        _eintragen(_nachLoeschung, schluessel, mandant);
      }
    }
    for (final zeichen in mandant.kennzeichen) {
      final wert = MandantErkennung.normalisiereKennzeichen(zeichen);
      if (wert.isNotEmpty) _eintragen(_nachKennzeichen, wert, mandant);
    }
  }

  static String _anfang(String name) =>
      name.substring(0, MandantErkennung.minPraefixLaenge);

  static void _eintragen(
    Map<String, List<Mandant>> eimer,
    String schluessel,
    Mandant mandant,
  ) => eimer.putIfAbsent(schluessel, () => []).add(mandant);

  static void _sammle(Map<int, Mandant> ziel, List<Mandant>? nachschub) {
    if (nachschub == null) return;
    for (final mandant in nachschub) {
      ziel[mandant.id] = mandant;
    }
  }
}
