import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:equatable/equatable.dart';

/// Die Auswahl, die auf der Registerseite sichtbar ist (§6.2).
///
/// Das Register führt **alle** Zeilen — laufende Vorgänge, abgeschlossene und
/// die übernommene Historie der Kanzlei. Bei tausenden Zeilen ist „alles
/// zeigen" ohne Einschränkung keine Ansicht mehr; deshalb filtert man hier nach
/// Stand, Jahrgangsspanne und Rechtsgebiet.
///
/// Dieser Filter wirkt **nur auf die Ansicht**. Was in die Spiegeldatei kommt,
/// entscheidet die Einstellung `registerExportFilter` — sonst hinge der Inhalt
/// einer Datei, die in der Cloud liegt und von anderen gelesen wird, davon ab,
/// was jemand zuletzt am Bildschirm eingestellt hatte.
///
/// **Er sortiert nicht.** Die Reihenfolge kommt seit Issue #109 aus dem
/// Backend (`RegisterZeilenBau.Aus`), zusammen mit den Zeilen selbst — vorher
/// war sie zweimal formuliert und konnte auseinanderlaufen. Ob sie vorwärts
/// oder rückwärts gelesen wird, entscheidet `RegisterReihenfolge`.
class RegisterFilter extends Equatable {
  /// Null heißt: alle. `true` zeigt nur abgeschlossene Zeilen — die Historie
  /// zählt dazu, sie ist per Definition abgeschlossen. `false` zeigt nur, was
  /// noch läuft.
  ///
  /// Bewusst kein `VorgangStatus`: Eine Registerzeile trägt keinen — die
  /// Historie hat nie einen gehabt, und der Endpunkt liefert von den Vorgängen
  /// nur, ob sie abgeschlossen sind. Ein Dropdown mit „Angefragt … Versendet"
  /// über einer Liste, die zum größten Teil aus Historie besteht, verspräche
  /// eine Auswahl, die es nicht gibt.
  final bool? abgeschlossen;

  /// Die Jahrgangsspanne, beide Grenzen einschließlich; null heißt „offen".
  ///
  /// Eine Spanne statt eines einzelnen Jahrgangs, weil die Frage am Register
  /// fast nie „genau 2021" lautet, sondern „die letzten Jahre" — und weil ein
  /// Chip je Jahrgang bei einem Registerbuch ab 2018 eine Leiste ergibt, die
  /// breiter ist als die Tabelle darunter. Ein einzelner Jahrgang ist der
  /// Sonderfall `von == bis` ([imJahr]).
  final int? vonJahr;
  final int? bisJahr;

  /// Rechtsgebiet in Anzeigeform („Verkehrsrecht"); null heißt: alle.
  /// Verglichen wird über [RechtsgebietWert.gleich], damit der
  /// kleingeschriebene Altbestand dieselben Treffer liefert.
  final String? rechtsgebiet;

  /// Woher die Zeile stammt ([RegisterQuellen.vorgang] oder
  /// [RegisterQuellen.historie]); null heißt: beides.
  ///
  /// Der praktische Fall ist das Ausblenden: Nach der Übernahme besteht das
  /// Register zum größten Teil aus Historie, und wer die laufende Arbeit der
  /// Kanzlei sehen will, sucht sie zwischen tausenden Altzeilen. Die
  /// Gegenrichtung — nur Historie — ist der Blick beim Nacharbeiten des
  /// Imports.
  final String? quelle;

  const RegisterFilter({
    this.abgeschlossen,
    this.vonJahr,
    this.bisJahr,
    this.rechtsgebiet,
    this.quelle,
  });

  static const RegisterFilter alle = RegisterFilter();

  /// Genau ein Jahrgang — was ein Klick auf einen Jahrgangs-Chip meint.
  const RegisterFilter.imJahr(int jahrgang)
    : abgeschlossen = null,
      vonJahr = jahrgang,
      bisJahr = jahrgang,
      rechtsgebiet = null,
      quelle = null;

  bool get istLeer =>
      abgeschlossen == null &&
      vonJahr == null &&
      bisJahr == null &&
      rechtsgebiet == null &&
      quelle == null;

  /// Kopie mit geänderten Feldern. Anders als sonst im Projekt setzt `null`
  /// hier **zurück** — „alle Zeilen" ist der Normalfall und muss mit einem
  /// Klick erreichbar sein.
  ///
  /// Die Spanne bleibt dabei gültig: Wer „von" über „bis" schiebt, zieht die
  /// andere Grenze mit, statt eine leere Tabelle zu bekommen und selbst darauf
  /// zu kommen, dass er zwei Felder anfassen muss.
  RegisterFilter mit({
    bool? abgeschlossen,
    int? vonJahr,
    int? bisJahr,
    String? rechtsgebiet,
    String? quelle,
    bool abgeschlossenLoeschen = false,
    bool jahrLoeschen = false,
    bool rechtsgebietLoeschen = false,
    bool quelleLoeschen = false,
  }) {
    var neuVon = jahrLoeschen ? null : vonJahr ?? this.vonJahr;
    var neuBis = jahrLoeschen ? null : bisJahr ?? this.bisJahr;
    if (neuVon != null && neuBis != null && neuVon > neuBis) {
      if (vonJahr != null) {
        neuBis = neuVon;
      } else {
        neuVon = neuBis;
      }
    }
    return RegisterFilter(
      abgeschlossen: abgeschlossenLoeschen
          ? null
          : abgeschlossen ?? this.abgeschlossen,
      vonJahr: neuVon,
      bisJahr: neuBis,
      rechtsgebiet: rechtsgebietLoeschen
          ? null
          : rechtsgebiet ?? this.rechtsgebiet,
      quelle: quelleLoeschen ? null : quelle ?? this.quelle,
    );
  }

  bool passt(RegisterZeile zeile) =>
      (abgeschlossen == null || zeile.abgeschlossen == abgeschlossen) &&
      _jahrPasst(zeile.jahr) &&
      (quelle == null || zeile.quelle == quelle) &&
      (rechtsgebiet == null ||
          RechtsgebietWert.gleich(zeile.rechtsgebiet, rechtsgebiet));

  /// Eine Zeile ohne lesbare Jahreszahl fällt aus jeder Spanne heraus — sie
  /// lässt sich nicht einordnen, und sie stillschweigend durchzulassen hieße,
  /// eine Auswahl zu zeigen, die nicht gilt. Ohne Spanne bleibt sie sichtbar.
  bool _jahrPasst(String jahr) {
    if (vonJahr == null && bisJahr == null) return true;
    final wert = int.tryParse(jahr);
    if (wert == null) return false;
    return (vonJahr == null || wert >= vonJahr!) &&
        (bisJahr == null || wert <= bisJahr!);
  }

  /// Wendet den Filter an und lässt die Reihenfolge, wie sie kam: Jahrgang
  /// aufsteigend, darin nach laufender Nummer, Zeilen ohne Nummer hinten am
  /// Jahrgang. Diese Reihenfolge stellt das Backend her — hier sie ein zweites
  /// Mal zu formulieren, hieße sie zweimal pflegen zu müssen.
  List<RegisterZeile> anwenden(List<RegisterZeile> zeilen) =>
      zeilen.where(passt).toList();

  /// Die vorkommenden Jahrgänge als Zahl, neueste zuerst — die Auswahl der
  /// beiden Felder „Von" und „Bis".
  static List<int> jahre(List<RegisterZeile> zeilen) {
    final jahre = <int>{
      for (final zeile in zeilen) ?int.tryParse(zeile.jahr),
    }.toList();
    jahre.sort((a, b) => b.compareTo(a));
    return jahre;
  }

  /// Die Rechtsgebiets-Auswahl der Filterleiste: der Katalog (§7.1) in seiner
  /// Reihenfolge, dahinter alphabetisch, was **nur im Bestand** vorkommt —
  /// etwa Vertragsrecht (kein Katalogeintrag, kein Kürzel) oder Altwerte aus
  /// dem übernommenen Registerbuch. Ohne die Bestandswerte wäre der alte
  /// Fehler zurück: Zeilen, nach denen niemand filtern kann, weil die Auswahl
  /// ihren Wert nicht anbietet.
  static List<String> rechtsgebiete(
    List<RegisterZeile> zeilen, {
    List<String> katalog = const [],
  }) {
    // Katalog dedupliziert übernehmen: mehrere Kürzel dürfen auf dasselbe
    // Rechtsgebiet zeigen, im Dropdown steht es trotzdem nur einmal.
    final bekannt = <String>{};
    final auswahl = <String>[];
    for (final name in katalog) {
      if (bekannt.add(RechtsgebietWert.normalisiert(name))) auswahl.add(name);
    }
    final nurBestand = <String, String>{};
    for (final zeile in zeilen) {
      final schluessel = RechtsgebietWert.normalisiert(zeile.rechtsgebiet);
      if (schluessel.isEmpty || bekannt.contains(schluessel)) continue;
      nurBestand[schluessel] = RechtsgebietWert.anzeige(zeile.rechtsgebiet);
    }
    final zusatz = nurBestand.values.toList()..sort();
    return [...auswahl, ...zusatz];
  }

  @override
  List<Object?> get props => [
    abgeschlossen,
    vonJahr,
    bisJahr,
    rechtsgebiet,
    quelle,
  ];
}
