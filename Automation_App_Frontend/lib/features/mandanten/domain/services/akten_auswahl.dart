import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/akten_auswahl_eintrag.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/services/ordnername_vorschlag.dart';

/// Baut die Liste für „Akte zuordnen" an der Mandantenkarte (#132): alle
/// gescannten Ordner außer den eigenen, geordnet nach [AktenAuswahlArt].
///
/// Geordnet wird **einmal** beim Öffnen ([fuer]), gesucht danach nur noch
/// darin ([filtere]): Der Namensvorschlag liest je Ordner die Präfixtabelle,
/// und das bei rund 4000 Ordnern je Tastendruck zu wiederholen, wäre die
/// Suche, die hinter der Eingabe herläuft.
class AktenAuswahl {
  const AktenAuswahl._();

  /// [zugeordnet] sind die zugeordneten Ordner des **ganzen** Registers,
  /// [ohneMandantenbezug] die vermerkten — beides aus dem Zustand der
  /// Übersicht.
  static List<AktenAuswahlEintrag> fuer({
    required Mandant mandant,
    required List<Akte> akten,
    required OrdnernamenMenge zugeordnet,
    required OrdnernamenMenge ohneMandantenbezug,
  }) {
    final eigene = OrdnernamenMenge(mandant.aktenOrdnernamen);
    // Je Art eine Liste statt eines Sortierens: `List.sort` ist in Dart nicht
    // stabil, und die Scan-Reihenfolge innerhalb einer Art soll bleiben.
    final nachArt = {
      for (final art in AktenAuswahlArt.values) art: <AktenAuswahlEintrag>[],
    };

    for (final akte in akten) {
      final name = akte.ordnername;
      if (eigene.enthaelt(name)) continue;
      final vermerkt = ohneMandantenbezug.enthaelt(name);
      final art = zugeordnet.enthaelt(name)
          ? AktenAuswahlArt.fremdZugeordnet
          : passtZumNamen(name, mandant)
          ? AktenAuswahlArt.namensvorschlag
          : vermerkt
          ? AktenAuswahlArt.ohneMandantenbezug
          : AktenAuswahlArt.offen;
      nachArt[art]!.add(
        AktenAuswahlEintrag(akte: akte, art: art, vermerkt: vermerkt),
      );
    }

    return [for (final art in AktenAuswahlArt.values) ...nachArt[art]!];
  }

  /// Die Einträge, deren Ordnername [suche] enthält — ohne Rücksicht auf die
  /// Schreibweise, in der Reihenfolge von [fuer].
  static List<AktenAuswahlEintrag> filtere(
    List<AktenAuswahlEintrag> eintraege,
    String suche,
  ) {
    final begriff = suche.trim().toLowerCase();
    if (begriff.isEmpty) return eintraege;
    return [
      for (final eintrag in eintraege)
        if (eintrag.akte.ordnername.toLowerCase().contains(begriff)) eintrag,
    ];
  }

  /// Ob der Ordner dem Namen nach zu [mandant] gehört. Verglichen wird der
  /// **ganze** Rest hinter dem Aktentyp-Präfix mit dem Namen des Mandanten —
  /// als Nachname allein, als „Vorname Nachname" oder als „Nachname Vorname".
  /// Die echten Ordner tragen meist nur den Nachnamen (siehe
  /// `nameVorschlagAusOrdner`); ein fehlender Vorname schließt nichts aus.
  ///
  /// Nicht über Vor- und Nachname aus `nameVorschlagAusOrdner`: Der teilt am
  /// ersten Leerzeichen und hält bei „VUnfallursache von der Heide" „von" für
  /// den Vornamen — ein mehrteiliger Nachname passte dann nie.
  static bool passtZumNamen(String ordnername, Mandant mandant) {
    final nachname = _vergleichsform(mandant.nachname);
    if (nachname.isEmpty) return false;

    final vorschlag = nameVorschlagAusOrdner(ordnername);
    final rest = _vergleichsform('${vorschlag.vorname} ${vorschlag.nachname}');
    if (rest == nachname) return true;

    final vorname = _vergleichsform(mandant.vorname);
    if (vorname.isNotEmpty) {
      return rest == '$vorname $nachname' || rest == '$nachname $vorname';
    }
    // Der Ordner nennt einen Vornamen, der Mandant keinen: Genau ein Wort
    // vor dem Nachnamen darf dann stehen.
    if (!rest.endsWith(' $nachname')) return false;
    return !rest.substring(0, rest.length - nachname.length - 1).contains(' ');
  }

  /// Kleingeschrieben, getrimmt, Leerraum zu je einem Leerzeichen.
  static String _vergleichsform(String text) =>
      text.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
}
