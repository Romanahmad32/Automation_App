import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Erkennt, zu welchem Vorgang eine Posteingangsnachricht gehört — ein reiner
/// Dienst ohne Flutter, ohne Cubit und ohne Repository.
///
/// **Er ändert nie etwas.** Er liest die übergebenen [vorgaenge] und gibt
/// einen Wert zurück; was damit geschieht, entscheidet der Anwalt in der
/// Vorschlagskarte (§4.3: Vorschlag, keine Entscheidung).
///
/// Die Stufen in der Reihenfolge, in der gefragt wird:
///
/// 1. **Sicher** — das Zeichen (bzw. die volle Referenz) steht im Betreff. Das
///    trägt, weil die App ihr Zeichen selbst in den Betreff ihrer Mails
///    schreibt und Antworten es zurücktragen.
/// 2. **Sicher** — die Schadennummer steht im Betreff. Das ist
///    `antwort.versicherungsscheinNr`; kürzere Zeichenfolgen als
///    [mindestlaengeSchadennummer] treffen zufällig und zählen deshalb nicht.
/// 3. **Vermutet** — die Absenderadresse gehört zum Mandanten oder zum
///    Versicherer eines noch **offenen** Vorgangs.
///
/// Treffen auf einer Stufe mehrere Vorgänge zu, ist das Ergebnis `null`:
/// lieber nichts behaupten als das Falsche. Ein falsch zugeordneter Schriftsatz
/// kostet mehr als ein fehlender Vorschlag.
///
/// Verglichen wird durchweg ohne Rücksicht auf die Schreibweise — Betreff und
/// Zeichen über [Vorgang.normalizeReferenz] (Großschreibung, ein Leerzeichen),
/// Adressen getrimmt, kleingeschrieben und ohne spitze Klammern.
class VorgangsbezugErkenner {
  const VorgangsbezugErkenner({
    required this.vorgaenge,
    this.mandantenAdressen = const {},
    this.versichererAdressen = const {},
  });

  /// Ab dieser Länge gilt eine Schadennummer als tragfähig. Kürzere Nummern
  /// stecken zufällig in jedem zweiten Betreff („Az. 12345").
  static const int mindestlaengeSchadennummer = 6;

  final List<Vorgang> vorgaenge;

  /// Mandanten-Id → E-Mail-Adresse. `Vorgang` trägt selbst keine Adresse,
  /// deshalb kommt sie von außen (aus dem Mandantenregister).
  final Map<int, String> mandantenAdressen;

  /// Versicherername → E-Mail-Adresse aus der Versicherer-Wissensbasis.
  final Map<String, String> versichererAdressen;

  /// Der Bezug einer Mail allein aus den Kopfdaten der Liste — oder null,
  /// wenn keiner erkennbar oder das Ergebnis mehrdeutig ist.
  Vorgangsbezug? fuer(PosteingangEintrag eintrag) {
    final betreff = Vorgang.normalizeReferenz(eintrag.betreff);
    return _ersteStufe([
      _zeichenTreffer(betreff, 'im Betreff'),
      _schadennummerTreffer(betreff, 'im Betreff'),
      _adressTreffer(eintrag.absenderAdresse ?? eintrag.absender),
    ]);
  }

  /// Der Bezug im geöffneten Detail, wo zusätzlich der Nachrichtentext
  /// vorliegt. Zeichen und Schadennummer stehen oft nur im Zitat einer
  /// Antwort und nicht mehr im Betreff — deshalb zwei weitere Stufen, aber
  /// erst **nach** dem Betreff: Was dort steht, ist das Verlässlichere.
  Vorgangsbezug? fuerInhalt(
    PosteingangEintrag eintrag,
    PosteingangInhalt inhalt,
  ) {
    final betreff = Vorgang.normalizeReferenz(eintrag.betreff);
    final nachricht = Vorgang.normalizeReferenz(inhalt.text);
    return _ersteStufe([
      _zeichenTreffer(betreff, 'im Betreff'),
      _schadennummerTreffer(betreff, 'im Betreff'),
      _zeichenTreffer(nachricht, 'in der Nachricht'),
      _schadennummerTreffer(nachricht, 'in der Nachricht'),
      _adressTreffer(
        inhalt.absenderAdresse ?? eintrag.absenderAdresse ?? eintrag.absender,
      ),
    ]);
  }

  /// Die erste Stufe, die überhaupt etwas findet, entscheidet — und zwar
  /// abschließend: Sind es dort mehrere Vorgänge, endet die Suche mit `null`,
  /// statt auf die schwächere nächste Stufe auszuweichen.
  Vorgangsbezug? _ersteStufe(List<List<Vorgangsbezug>> stufen) {
    for (final stufe in stufen) {
      if (stufe.isEmpty) continue;
      return stufe.length == 1 ? stufe.single : null;
    }
    return null;
  }

  List<Vorgangsbezug> _zeichenTreffer(String text, String quelle) {
    if (text.isEmpty) return const [];
    final treffer = <Vorgangsbezug>[];
    for (final vorgang in vorgaenge) {
      final gesucht = {
        vorgang.zeichen,
        vorgang.referenz,
      }.map(Vorgang.normalizeReferenz).where((wert) => wert.isNotEmpty);
      if (!gesucht.any(text.contains)) continue;
      treffer.add(
        Vorgangsbezug(
          vorgang: vorgang,
          sicherheit: BezugSicherheit.sicher,
          grund: 'Zeichen ${vorgang.zeichen} steht $quelle',
        ),
      );
    }
    return treffer;
  }

  List<Vorgangsbezug> _schadennummerTreffer(String text, String quelle) {
    if (text.isEmpty) return const [];
    final treffer = <Vorgangsbezug>[];
    for (final vorgang in vorgaenge) {
      final nummer = vorgang.antwort?.versicherungsscheinNr?.trim() ?? '';
      if (nummer.length < mindestlaengeSchadennummer) continue;
      if (!text.contains(Vorgang.normalizeReferenz(nummer))) continue;
      treffer.add(
        Vorgangsbezug(
          vorgang: vorgang,
          sicherheit: BezugSicherheit.sicher,
          grund: 'Schadennummer $nummer steht $quelle',
        ),
      );
    }
    return treffer;
  }

  List<Vorgangsbezug> _adressTreffer(String? absender) {
    final adresse = _adresse(absender);
    if (adresse.isEmpty) return const [];
    final treffer = <Vorgangsbezug>[];
    for (final vorgang in vorgaenge) {
      // Ein abgeschlossener Vorgang wird nicht mehr vermutet: Mandant und
      // Versicherer schreiben weiter, aber ihre Post gehört dann zu etwas
      // Neuem — ein Vorschlag auf den alten Vorgang führte in die Irre.
      if (vorgang.status.istAbgeschlossen) continue;
      final bezug = _adressBezug(vorgang, adresse);
      if (bezug != null) treffer.add(bezug);
    }
    return treffer;
  }

  Vorgangsbezug? _adressBezug(Vorgang vorgang, String adresse) {
    final mandant = _adresse(mandantenAdressen[vorgang.mandantId]);
    if (mandant.isNotEmpty && mandant == adresse) {
      return Vorgangsbezug(
        vorgang: vorgang,
        sicherheit: BezugSicherheit.vermutet,
        grund: _absenderGrund('der Mandant', vorgang.mandantName),
      );
    }
    final name = vorgang.antwort?.versichererName;
    final ausKatalog = _versichererAdresse(name);
    final ausAntwort = _adresse(vorgang.antwort?.versichererEmail);
    final passt =
        (ausKatalog.isNotEmpty && ausKatalog == adresse) ||
        (ausAntwort.isNotEmpty && ausAntwort == adresse);
    if (!passt) return null;
    return Vorgangsbezug(
      vorgang: vorgang,
      sicherheit: BezugSicherheit.vermutet,
      grund: _absenderGrund('der Versicherer', name),
    );
  }

  String _absenderGrund(String rolle, String? name) {
    final klar = (name ?? '').trim();
    return klar.isEmpty
        ? 'Absender ist $rolle dieses Vorgangs'
        : 'Absender ist $rolle $klar';
  }

  /// Die reine, vergleichbare Adresse: ohne Klarnamen, ohne spitze Klammern,
  /// getrimmt und kleingeschrieben.
  String _adresse(String? wert) {
    final roh = (wert ?? '').trim();
    final start = roh.lastIndexOf('<');
    final ende = roh.lastIndexOf('>');
    final kern = start >= 0 && ende > start
        ? roh.substring(start + 1, ende)
        : roh;
    return kern.trim().toLowerCase();
  }

  /// Die Adresse zum Versicherernamen — auch der Name wird ohne Rücksicht auf
  /// die Schreibweise gesucht, denn er stammt aus der Antwortmail und nicht
  /// aus einer Auswahlliste.
  String _versichererAdresse(String? name) {
    final gesucht = (name ?? '').trim().toLowerCase();
    if (gesucht.isEmpty) return '';
    for (final eintrag in versichererAdressen.entries) {
      if (eintrag.key.trim().toLowerCase() == gesucht) {
        return _adresse(eintrag.value);
      }
    }
    return '';
  }
}
