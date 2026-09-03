import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:equatable/equatable.dart';

/// Die Auswahl, die auf der Registerseite sichtbar ist (§6.2).
///
/// Das Register führt **alle** Vorgänge, nicht nur die abgeschlossenen — sonst
/// wäre die Seite blind für alles, was gerade läuft. Damit sie trotzdem
/// benutzbar bleibt, filtert man hier nach Status, Jahrgang und Rechtsgebiet.
///
/// Dieser Filter wirkt **nur auf die Ansicht**. Was in die Spiegeldatei kommt,
/// entscheidet die Einstellung `registerExportFilter` — sonst hinge der Inhalt
/// einer Datei, die in der Cloud liegt und von anderen gelesen wird, davon ab,
/// was jemand zuletzt am Bildschirm eingestellt hatte.
class RegisterFilter extends Equatable {
  /// Null heißt: alle Status.
  final VorgangStatus? status;

  /// Vierstelliger Jahrgang; null heißt: alle Jahrgänge.
  final String? jahr;

  /// Rechtsgebiet in Anzeigeform („Verkehrsrecht"); null heißt: alle.
  /// Verglichen wird über [RechtsgebietWert.gleich], damit der
  /// kleingeschriebene Altbestand dieselben Treffer liefert.
  final String? rechtsgebiet;

  const RegisterFilter({this.status, this.jahr, this.rechtsgebiet});

  static const RegisterFilter alle = RegisterFilter();

  bool get istLeer => status == null && jahr == null && rechtsgebiet == null;

  /// Kopie mit geänderten Feldern. Anders als sonst im Projekt setzt `null`
  /// hier **zurück** — „alle Status" ist der Normalfall und muss mit einem
  /// Klick erreichbar sein.
  RegisterFilter mit({
    VorgangStatus? status,
    String? jahr,
    String? rechtsgebiet,
    bool statusLoeschen = false,
    bool jahrLoeschen = false,
    bool rechtsgebietLoeschen = false,
  }) => RegisterFilter(
    status: statusLoeschen ? null : status ?? this.status,
    jahr: jahrLoeschen ? null : jahr ?? this.jahr,
    rechtsgebiet: rechtsgebietLoeschen
        ? null
        : rechtsgebiet ?? this.rechtsgebiet,
  );

  bool passt(Vorgang vorgang) =>
      (status == null || vorgang.status == status) &&
      (jahr == null || jahrgang(vorgang) == jahr) &&
      (rechtsgebiet == null ||
          RechtsgebietWert.gleich(vorgang.rechtsgebiet, rechtsgebiet));

  /// Wendet den Filter an und sortiert wie die Registerdatei: Jahrgang
  /// aufsteigend, darin nach laufender Nummer. Zeilen ohne Nummer hängen hinten
  /// am Jahrgang — sie bekommen ihre Nummer erst beim Abschluss und würfen
  /// sonst dabei die Reihenfolge um.
  List<Vorgang> anwenden(List<Vorgang> vorgaenge) {
    final gefiltert = vorgaenge.where(passt).toList();
    gefiltert.sort((a, b) {
      final jahre = jahrgang(a).compareTo(jahrgang(b));
      if (jahre != 0) return jahre;
      final an = a.laufendeNummer;
      final bn = b.laufendeNummer;
      if (an == null && bn == null) return a.referenz.compareTo(b.referenz);
      if (an == null) return 1;
      if (bn == null) return -1;
      return an.compareTo(bn);
    });
    return gefiltert;
  }

  /// Nur Ziffern, nichts sonst. `int.tryParse` stand hier vorher und nahm auch
  /// ein Vorzeichen an: Aus dem Jahr „-1" wurde der Jahrgang „20-1", während
  /// das Backend auf das Datum zurückfiel. Darts `\d` ist ASCII-only und passt
  /// damit genau zu `char.IsAsciiDigit` drüben.
  static final RegExp _nurZiffern = RegExp(r'^\d+$');

  /// Vierstelliger Jahrgang eines Vorgangs. `Vorgang.jahr` steht zweistellig
  /// („26"), weil es aus dem Zeichen stammt; die Überschriften im Register sind
  /// vierstellig. Ohne das Feld entscheidet das Abschlussdatum. Muss dieselbe
  /// Antwort geben wie `RegisterZeilenBau.Jahrgang` im Backend — sonst zeigt die
  /// App einen anderen Jahrgang an, als in der Datei steht; festgehalten in
  /// `register_paritaet_test.dart`.
  static String jahrgang(Vorgang vorgang) {
    final jahr = (vorgang.jahr ?? '').trim();
    if (jahr.length == 4 && _nurZiffern.hasMatch(jahr)) return jahr;
    if (jahr.length == 2 && _nurZiffern.hasMatch(jahr)) return '20$jahr';
    return '${(vorgang.abgeschlossenAm ?? vorgang.angefragtAm).year}';
  }

  /// Die vorkommenden Jahrgänge, neueste zuerst — die Auswahl der Filterleiste.
  static List<String> jahrgaenge(List<Vorgang> vorgaenge) {
    final jahre = vorgaenge.map(jahrgang).toSet().toList();
    jahre.sort((a, b) => b.compareTo(a));
    return jahre;
  }

  /// Die Rechtsgebiets-Auswahl der Filterleiste: der Katalog (§7.1) in seiner
  /// Reihenfolge, dahinter alphabetisch, was **nur im Bestand** vorkommt —
  /// etwa Vertragsrecht (kein Katalogeintrag, kein Kürzel) oder Altwerte.
  /// Ohne die Bestandswerte wäre der alte Fehler zurück: Zeilen, nach denen
  /// niemand filtern kann, weil die Auswahl ihren Wert nicht anbietet.
  static List<String> rechtsgebiete(
    List<Vorgang> vorgaenge, {
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
    for (final vorgang in vorgaenge) {
      final schluessel = RechtsgebietWert.normalisiert(vorgang.rechtsgebiet);
      if (schluessel.isEmpty || bekannt.contains(schluessel)) continue;
      nurBestand[schluessel] = RechtsgebietWert.anzeige(vorgang.rechtsgebiet);
    }
    final zusatz = nurBestand.values.toList()..sort();
    return [...auswahl, ...zusatz];
  }

  @override
  List<Object?> get props => [status, jahr, rechtsgebiet];
}
