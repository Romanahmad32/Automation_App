import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';

/// Prüft die Ordnerangaben einer Importdatei gegen den wirklich vorhandenen
/// Bestand unter dem Stammordner.
///
/// Der Anlass: Die Datei entsteht maschinell — ein KI-Agent kann einen
/// Ordnernamen **erfinden**, verschreiben oder aus einem Aktentext ableiten,
/// der nie so auf der Platte stand. Bis hierher wurde ein solcher Name
/// klaglos gespeichert: der Ordner war danach nie auffindbar, die Mandantenkarte
/// zeigte eine Akte, die es nicht gibt, und die Zähler des Zuordnungsstapels
/// standen still falsch. Ein erfundener Name ist damit schlimmer als eine
/// fehlende Zuordnung, weil er wie eine erledigte aussieht.
///
/// Verglichen wird über [OrdnernamenMenge] — dieselbe Auffassung von „gleicher
/// Ordner" wie überall sonst (Windows kennt „VUnfallursache Mark" und
/// „Vunfallursache Mark" als einen). Ein eigener Vergleich hier meldete Zeilen
/// als unbekannt, die der Import gleich darauf zuordnet.
class OrdnerPruefung {
  const OrdnerPruefung._();

  /// Die Zeilennummern in [MandantenImportDatei.mandanten], die mindestens
  /// einen Ordner nennen, den es im Stammordner nicht gibt. Die Nummer ist der
  /// Index in der Liste — dieselbe Zählung wie `ImportEintrag.zeile`, damit
  /// Bericht und Prüfung auf dieselbe Zeile zeigen.
  static Set<int> unbekannteZeilen({
    required MandantenImportDatei datei,
    required OrdnernamenMenge vorhandene,
  }) {
    if (vorhandene.isEmpty) return const {};
    final zeilen = <int>{};
    for (var zeile = 0; zeile < datei.mandanten.length; zeile++) {
      final unbekannt = datei.mandanten[zeile].aktenOrdnernamen.any(
        (ordnername) => !istBekannt(ordnername, vorhandene),
      );
      if (unbekannt) zeilen.add(zeile);
    }
    return zeilen;
  }

  /// Die unbekannten Ordner aus [MandantenImportDatei.ohneMandantenbezug].
  ///
  /// Der zweite Topf wird ausdrücklich mitgeprüft: Ein Vermerk auf einen
  /// Ordner, den es nicht gibt, ist genauso wertlos wie eine Zuordnung darauf —
  /// nur fällt er noch weniger auf, weil ihn keine Mandantenkarte zeigt.
  static List<String> unbekannteOhneBezug({
    required MandantenImportDatei datei,
    required OrdnernamenMenge vorhandene,
  }) {
    if (vorhandene.isEmpty) return const [];
    return [
      for (final ordnername in datei.ohneMandantenbezug)
        if (!istBekannt(ordnername, vorhandene)) ordnername,
    ];
  }

  /// Ob [ordnername] im gescannten Bestand steht.
  ///
  /// **Ist [vorhandene] leer, gilt jeder Name als bekannt.** Eine leere Menge
  /// heißt nicht „es gibt keine Ordner", sondern „es liegt kein Scan vor" — der
  /// Stammordner ist nicht eingerichtet, liegt auf einem Netzlaufwerk, das
  /// gerade fehlt, oder die Datei wird auf einem anderen Arbeitsplatz geprüft.
  /// Würde hier blockiert, wäre der Import auf jeder Maschine ohne Stammordner
  /// unbenutzbar, und der Anwalt sähe eine Warnung über jede einzelne Zeile,
  /// die er nicht berichtigen kann.
  ///
  /// Ein leerer Name nennt keinen Ordner und ist deshalb auch keiner, der
  /// fehlt: er ist eine krumme Zeile, die der Import ohnehin übergeht. Ihn
  /// hier zu melden hielte die Übernahme auf, ohne dass es etwas zu berichtigen
  /// gäbe.
  static bool istBekannt(String ordnername, OrdnernamenMenge vorhandene) {
    if (vorhandene.isEmpty) return true;
    if (ordnername.trim().isEmpty) return true;
    return vorhandene.enthaelt(ordnername);
  }
}
