import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';

/// Ein Wiedererkennungs-Treffer: welcher Registereintrag zu den freien
/// Eingaben passt und warum (für den Hinweis „Meinten Sie …?").
class MandantVorschlag {
  final Mandant mandant;
  final String begruendung;

  const MandantVorschlag({required this.mandant, required this.begruendung});
}

/// Eine Zeile, zu der ein Vorschlag gesucht wird: die Nummer, unter der der
/// Aufrufer sie wiederfindet, und die beiden Namensteile.
class AehnlichkeitsZeile {
  final int zeile;
  final String vorname;
  final String nachname;

  const AehnlichkeitsZeile({
    required this.zeile,
    this.vorname = '',
    this.nachname = '',
  });
}

/// Register und Zeilen in **einem** Argument — die Form, die
/// [MandantErkennung.findeZuZeilen] in einem eigenen Isolate (`compute`)
/// aufrufbar macht.
///
/// Der Anlass ist die Größenordnung des Imports: eine Datei über den ganzen
/// Bestand hat viertausend Zeilen, und jede läuft über mehrere tausend
/// Registereinträge mit Levenshtein-Vergleich. Im Oberflächen-Isolat gerechnet
/// steht die App dabei still — ein Fehler, der in der Kanzlei auffällt und
/// nicht in der Prüfkette.
class AehnlichkeitsAuftrag {
  final List<Mandant> mandanten;
  final List<AehnlichkeitsZeile> zeilen;

  const AehnlichkeitsAuftrag({
    this.mandanten = const [],
    this.zeilen = const [],
  });
}

/// Erkennt beim freien Erfassen im „Vorgang starten"-Formular, ob die Eingaben
/// zu einem bereits gespeicherten Mandanten passen — bevor versehentlich ein
/// Duplikat entsteht. Zwei Signale:
///
/// * ein beim Mandanten hinterlegtes **Kfz-Kennzeichen** (exakter Vergleich,
///   tolerant gegenüber Schreibweise) — das stärkste Signal,
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

    final kz = _normalisiereKennzeichen(kennzeichen);
    if (kz.length >= 4) {
      for (final mandant in mandanten) {
        final passt = mandant.kennzeichen.any(
          (k) => _normalisiereKennzeichen(k) == kz,
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

    final nach = _normalisiereName(nachname);
    if (nach.length >= 2) {
      final vor = _normalisiereName(vorname);
      for (final mandant in mandanten) {
        if (gesehen.contains(mandant.id)) continue;
        if (!_nachnamePasst(nach, _normalisiereName(mandant.nachname))) {
          continue;
        }
        if (!_vornamePasst(vor, _normalisiereName(mandant.vorname))) continue;
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

  /// [finde] über viele Zeilen auf einmal — ein Argument, ein Rückgabewert,
  /// damit der Aufruf durch `compute` in ein eigenes Isolate passt.
  ///
  /// Geliefert werden nur Zeilen **mit** Treffer: eine Karte voller leerer
  /// Listen kostete bei viertausend Zeilen Platz und sagte nichts.
  static Map<int, List<MandantVorschlag>> findeZuZeilen(
    AehnlichkeitsAuftrag auftrag,
  ) {
    final ergebnis = <int, List<MandantVorschlag>>{};
    for (final zeile in auftrag.zeilen) {
      final treffer = finde(
        mandanten: auftrag.mandanten,
        vorname: zeile.vorname,
        nachname: zeile.nachname,
      );
      if (treffer.isNotEmpty) ergebnis[zeile.zeile] = treffer;
    }
    return ergebnis;
  }

  /// Nachname passt bei Gleichheit, Tippbeginn (in beide Richtungen ab drei
  /// Zeichen) oder genau einem Tippfehler — inklusive Buchstabendreher —
  /// (ab vier Zeichen).
  static bool _nachnamePasst(String eingabe, String gespeichert) {
    if (gespeichert.isEmpty) return false;
    if (eingabe == gespeichert) return true;
    if (eingabe.length >= 3 &&
        (gespeichert.startsWith(eingabe) || eingabe.startsWith(gespeichert))) {
      return true;
    }
    if (eingabe.length >= 4 && gespeichert.length >= 4) {
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

  /// Kennzeichen auf die reinen Zeichen reduzieren (Bindestrich/Leerzeichen
  /// egal): „HG-E 1427" und „hge1427" gelten als gleich.
  static String _normalisiereKennzeichen(String kennzeichen) =>
      kennzeichen.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');

  static String _normalisiereName(String name) => name
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
