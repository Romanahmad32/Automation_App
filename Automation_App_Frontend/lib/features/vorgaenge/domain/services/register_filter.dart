import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:equatable/equatable.dart';

/// Die Auswahl, die auf der Registerseite sichtbar ist (§6.2).
///
/// Das Register führt **alle** Zeilen — laufende Vorgänge, abgeschlossene und
/// die übernommene Historie der Kanzlei. Bei tausenden Zeilen ist „alles
/// zeigen" ohne Einschränkung keine Ansicht mehr; deshalb filtert man hier nach
/// Stand, Jahrgang und Rechtsgebiet.
///
/// Dieser Filter wirkt **nur auf die Ansicht**. Was in die Spiegeldatei kommt,
/// entscheidet die Einstellung `registerExportFilter` — sonst hinge der Inhalt
/// einer Datei, die in der Cloud liegt und von anderen gelesen wird, davon ab,
/// was jemand zuletzt am Bildschirm eingestellt hatte.
///
/// **Er sortiert nicht.** Die Reihenfolge kommt seit Issue #109 aus dem
/// Backend (`RegisterZeilenBau.Aus`), zusammen mit den Zeilen selbst — vorher
/// war sie zweimal formuliert und konnte auseinanderlaufen.
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

  /// Vierstelliger Jahrgang; null heißt: alle Jahrgänge.
  final String? jahr;

  /// Rechtsgebiet in Anzeigeform („Verkehrsrecht"); null heißt: alle.
  /// Verglichen wird über [RechtsgebietWert.gleich], damit der
  /// kleingeschriebene Altbestand dieselben Treffer liefert.
  final String? rechtsgebiet;

  const RegisterFilter({this.abgeschlossen, this.jahr, this.rechtsgebiet});

  static const RegisterFilter alle = RegisterFilter();

  bool get istLeer =>
      abgeschlossen == null && jahr == null && rechtsgebiet == null;

  /// Kopie mit geänderten Feldern. Anders als sonst im Projekt setzt `null`
  /// hier **zurück** — „alle Zeilen" ist der Normalfall und muss mit einem
  /// Klick erreichbar sein.
  RegisterFilter mit({
    bool? abgeschlossen,
    String? jahr,
    String? rechtsgebiet,
    bool abgeschlossenLoeschen = false,
    bool jahrLoeschen = false,
    bool rechtsgebietLoeschen = false,
  }) => RegisterFilter(
    abgeschlossen: abgeschlossenLoeschen
        ? null
        : abgeschlossen ?? this.abgeschlossen,
    jahr: jahrLoeschen ? null : jahr ?? this.jahr,
    rechtsgebiet: rechtsgebietLoeschen
        ? null
        : rechtsgebiet ?? this.rechtsgebiet,
  );

  bool passt(RegisterZeile zeile) =>
      (abgeschlossen == null || zeile.abgeschlossen == abgeschlossen) &&
      (jahr == null || zeile.jahr == jahr) &&
      (rechtsgebiet == null ||
          RechtsgebietWert.gleich(zeile.rechtsgebiet, rechtsgebiet));

  /// Wendet den Filter an und lässt die Reihenfolge, wie sie kam: Jahrgang
  /// aufsteigend, darin nach laufender Nummer, Zeilen ohne Nummer hinten am
  /// Jahrgang. Diese Reihenfolge stellt das Backend her — hier sie ein zweites
  /// Mal zu formulieren, hieße sie zweimal pflegen zu müssen.
  List<RegisterZeile> anwenden(List<RegisterZeile> zeilen) =>
      zeilen.where(passt).toList();

  /// Die vorkommenden Jahrgänge, neueste zuerst — die Chips der Filterleiste.
  static List<String> jahrgaenge(List<RegisterZeile> zeilen) {
    final jahre = zeilen
        .map((zeile) => zeile.jahr)
        .where((jahr) => jahr.isNotEmpty)
        .toSet()
        .toList();
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
  List<Object?> get props => [abgeschlossen, jahr, rechtsgebiet];
}
