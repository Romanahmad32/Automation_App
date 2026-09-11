import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Ein Wiedererkennungs-Treffer: welcher Registereintrag zu den freien
/// Eingaben passt und warum (für den Hinweis „Meinten Sie …?").
class MandantVorschlag {
  final Mandant mandant;
  final String begruendung;

  const MandantVorschlag({required this.mandant, required this.begruendung});
}

/// Erkennt beim freien Erfassen im „Vorgang starten"-Formular, ob die Eingaben
/// zu einem bereits gespeicherten Mandanten passen — bevor versehentlich ein
/// Duplikat entsteht. Zwei Signale:
///
/// * ein beim Mandanten hinterlegtes **Kfz-Kennzeichen** — das stärkste
///   Signal. Verglichen über `gleichesKennzeichen`, dieselbe Regel wie
///   Zuordnung, Auswahlhilfe und Backend: Die Schreibweise zählt nicht, die
///   Aufteilung schon (`hge 1427` trifft `HG-E 1427`, `H-GE 1427` nicht — das
///   ist ein anderer Wagen, §4.2),
/// * ein **ähnlicher Nachname** (gleich, Tippbeginn oder ein Tippfehler),
///   verfeinert über den Vornamen, damit nicht jedes Familienmitglied
///   vorgeschlagen wird.
///
/// Nur ein Vorschlag, keine Automatik: Die Übernahme bleibt ein bewusster
/// Klick des Anwalts (Human-in-the-loop wie bei Captcha und Versand).
class MandantErkennung {
  const MandantErkennung._();

  /// Maximal so viele Vorschläge, damit der Hinweis kompakt bleibt.
  static const int maxVorschlaege = 3;

  /// Ab dieser Länge des eingegebenen Nachnamens zählt ein Tippbeginn
  /// (Präfix in eine der beiden Richtungen) als Treffer.
  static const int minPraefixLaenge = 3;

  /// Ab dieser Länge — auf **beiden** Seiten — zählt ein einzelner Tippfehler
  /// als Treffer. Kürzere Namen unterscheiden sich zu oft nur um ein Zeichen,
  /// ohne dasselbe zu meinen.
  static const int minTippfehlerLaenge = 4;

  /// Der kürzeste Nachname, zu dem überhaupt gesucht wird.
  static const int minNachnameLaenge = 2;

  /// Erst ab so vielen Zeichen — ohne Trennzeichen gezählt
  /// ([kennzeichenGrobschluessel]) — wird zum Kennzeichen gesucht.
  static const int minKennzeichenLaenge = 4;

  /// Liefert die passenden Registereinträge zu den aktuellen Eingaben,
  /// Kennzeichen-Treffer zuerst. Leer, wenn nichts (sicher genug) passt.
  static List<MandantVorschlag> finde({
    required List<Mandant> mandanten,
    String vorname = '',
    String nachname = '',
    String kennzeichen = '',
  }) {
    final ergebnis = <MandantVorschlag>[];
    final gesehen = <int>{};

    final schluessel = kennzeichenGrobschluessel(kennzeichen);
    if (schluessel.length >= minKennzeichenLaenge) {
      for (final mandant in mandanten) {
        // Der Grobschlüssel zuerst, weil er billig ist und der Banner bei
        // jedem Tastendruck das ganze Register fragt: Wo er abweicht, kann
        // `gleichesKennzeichen` nicht „gleich" sagen. Entscheiden tut nur das.
        final passt = mandant.kennzeichen.any(
          (k) =>
              kennzeichenGrobschluessel(k) == schluessel &&
              gleichesKennzeichen(k, kennzeichen),
        );
        if (passt && gesehen.add(mandant.id)) {
          ergebnis.add(
            MandantVorschlag(
              mandant: mandant,
              begruendung:
                  'Das Kennzeichen ${kennzeichen.trim().toUpperCase()} ist '
                  'bei diesem Mandanten hinterlegt.',
            ),
          );
        }
      }
    }

    final nach = normalisiereName(nachname);
    if (nach.length >= minNachnameLaenge) {
      final vor = normalisiereName(vorname);
      for (final mandant in mandanten) {
        if (gesehen.contains(mandant.id)) continue;
        if (!_nachnamePasst(nach, normalisiereName(mandant.nachname))) {
          continue;
        }
        if (!_vornamePasst(vor, normalisiereName(mandant.vorname))) continue;
        if (gesehen.add(mandant.id)) {
          ergebnis.add(
            MandantVorschlag(
              mandant: mandant,
              begruendung: 'Ähnlicher Name im Mandantenregister.',
            ),
          );
        }
      }
    }

    return ergebnis.length <= maxVorschlaege
        ? ergebnis
        : ergebnis.sublist(0, maxVorschlaege);
  }

  /// Nachname passt bei Gleichheit, Tippbeginn (in beide Richtungen ab drei
  /// Zeichen) oder genau einem Tippfehler — inklusive Buchstabendreher —
  /// (ab vier Zeichen).
  static bool _nachnamePasst(String eingabe, String gespeichert) {
    if (gespeichert.isEmpty) return false;
    if (eingabe == gespeichert) return true;
    if (eingabe.length >= minPraefixLaenge &&
        (gespeichert.startsWith(eingabe) || eingabe.startsWith(gespeichert))) {
      return true;
    }
    if (eingabe.length >= minTippfehlerLaenge &&
        gespeichert.length >= minTippfehlerLaenge) {
      // Abkürzung ohne Bedeutungsänderung: Unterscheiden sich die Längen um
      // mehr als 1, kostet allein das Angleichen schon mehr als einen Schritt —
      // der Abstand kann dann nicht ≤ 1 sein. Das erspart die volle Matrix im
      // häufigsten Fall und zählt beim Import über viertausend Zeilen.
      if ((eingabe.length - gespeichert.length).abs() > 1) return false;
      return _levenshtein(eingabe, gespeichert) <= 1;
    }
    return false;
  }

  /// Der Vorname verfeinert nur: Solange (noch) keiner erfasst ist, bleibt der
  /// Vorschlag stehen; sonst muss der Tippbeginn zusammenpassen.
  static bool _vornamePasst(String eingabe, String gespeichert) {
    if (eingabe.isEmpty || gespeichert.isEmpty) return true;
    return gespeichert.startsWith(eingabe) || eingabe.startsWith(gespeichert);
  }

  /// Der **Grobschlüssel** eines Kennzeichens: nur Buchstaben und Ziffern,
  /// großgeschrieben — `HG-E 1427`, `H-GE 1427` und `hge1427` ergeben alle
  /// `HGE1427`.
  ///
  /// **Nie zum Vergleichen.** Er wirft weg, wo die Buchstabengruppen getrennt
  /// sind, und damit das Unterscheidungszeichen: `HG-E 1427` und `H-GE 1427`
  /// sind zwei Wagen (§4.2), hier aber ein Schlüssel. Bis #147 verglich
  /// [finde] damit und schlug zum einen Wagen den Mandanten des anderen vor.
  ///
  /// Er taugt als Vorfilter ([finde], `MandantenNamensindex`) und als
  /// Längenmaß, weil er eine **Obermenge** ist: Wo `gleichesKennzeichen`
  /// „gleich" sagt, stimmen die Grobschlüssel überein — dieselben Zeichen, nur
  /// anders getrennt. Umgekehrt gilt das nicht.
  static String kennzeichenGrobschluessel(String kennzeichen) =>
      kennzeichen.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');

  /// Namen vergleichbar machen: getrimmt, kleingeschrieben, Umlaute
  /// aufgelöst. Öffentlich, weil `ImportAehnlichkeit` seinen Vorfilter über
  /// **dieselbe** Schreibweise legt — eine zweite Normalisierung daneben
  /// schlösse Namen aus, die [finde] gefunden hätte.
  static String normalisiereName(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');

  /// Damerau-Levenshtein-Distanz (Ersetzen/Einfügen/Löschen/Buchstabendreher
  /// zählen je 1) über die volle Matrix — die Namen sind kurz, das reicht für
  /// den Ein-Tippfehler-Vergleich. Der Dreher zählt mit, weil er der häufigste
  /// Tippfehler ist („Schmitd" soll „Schmidt" treffen).
  static int _levenshtein(String a, String b) {
    final d = List.generate(
      a.length + 1,
      (i) => List<int>.generate(
        b.length + 1,
        (j) => i == 0 ? j : (j == 0 ? i : 0),
      ),
    );
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final kosten = a[i - 1] == b[j - 1] ? 0 : 1;
        var minimum = d[i - 1][j - 1] + kosten;
        if (d[i][j - 1] + 1 < minimum) minimum = d[i][j - 1] + 1;
        if (d[i - 1][j] + 1 < minimum) minimum = d[i - 1][j] + 1;
        final dreher =
            i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1];
        if (dreher && d[i - 2][j - 2] + 1 < minimum) {
          minimum = d[i - 2][j - 2] + 1;
        }
        d[i][j] = minimum;
      }
    }
    return d[a.length][b.length];
  }
}
