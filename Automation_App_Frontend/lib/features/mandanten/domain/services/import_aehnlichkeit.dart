import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/mandanten_namensindex.dart';

/// Sucht zu den Zeilen einer Importvorschau ähnliche, bereits erfasste
/// Mandanten — der Hinweis „Meinten Sie …?" an genau der Stelle, an der sonst
/// eine Dublette entstünde.
///
/// Gerechnet wird mit [MandantErkennung], derselben Erkennung wie im Formular
/// „Vorgang starten". Ein zweiter Namensvergleich (im Backend oder hier) liefe
/// beim ersten Sonderfall auseinander, und dann schlüge das Register eine
/// Dublette ab, die der Import gerade noch als unbedenklich gezeigt hat. Diese
/// Klasse ist deshalb nur die **Einbettung**: welche Zeilen gefragt werden,
/// gegen welchen Ausschnitt des Registers, und mit welchem Nachnamen.
///
/// Drei Entscheidungen stecken darin:
///
/// * **Nur Zeilen mit [ImportArt.neu].** Wo der Dienst schon einen Mandanten
///   gefunden hat (`ergaenzt`, `unveraendert`) oder die Zeile ablehnt, wäre ein
///   Vorschlag daneben bestenfalls Lärm.
/// * **Ohne Nachnamen kein Vorschlag.** Ein Treffer allein über den Vornamen
///   wäre geraten, und geraten wird im Register nicht.
/// * **Ein Vorfilter davor** ([MandantenNamensindex]) — sonst rechnete eine
///   Vorschau mit 200 Zeilen gegen mehrere tausend Registereinträge, und zwar
///   nach jeder berichtigten Zeile erneut.
class ImportAehnlichkeit {
  const ImportAehnlichkeit._();

  /// Akademische Grade, die vor dem Nachnamen stehen können. Sie gehören nicht
  /// zum Namen: „Dr. Schmidt" und „Schmidt" sind derselbe Mensch, und ein
  /// Vergleich, der den Grad mitzählt, sähe darin zwei — vier Zeichen Abstand,
  /// also weit jenseits des einen erlaubten Tippfehlers.
  static const Set<String> titelwoerter = {
    'dr',
    'prof',
    'dipl',
    'ing',
    'med',
    'jur',
    'rer',
    'nat',
    'phil',
    'habil',
    'mag',
    'lic',
  };

  /// Vorschläge je Zeilennummer, für die ganze Vorschau in einem Zug. Zeilen
  /// ohne Fund fehlen in der Karte, statt leer darin zu stehen.
  ///
  /// [bericht] und [datei] stammen aus demselben Aufruf, die Zeilennummer
  /// trifft also; geprüft wird sie trotzdem, weil ein Fehlgriff sonst den
  /// Vorschlag einer fremden Zeile zeigte statt aufzufallen.
  static Map<int, List<MandantVorschlag>> zuVorschau({
    required ImportBericht bericht,
    required MandantenImportDatei datei,
    required List<Mandant> mandanten,
  }) {
    final ergebnis = <int, List<MandantVorschlag>>{};
    if (mandanten.isEmpty || bericht.eintraege.isEmpty) return ergebnis;

    final index = MandantenNamensindex(mandanten);
    for (final eintrag in bericht.eintraege) {
      if (eintrag.art != ImportArt.neu) continue;
      if (eintrag.zeile < 0 || eintrag.zeile >= datei.mandanten.length) {
        continue;
      }
      final vorschlaege = zuZeile(
        zeile: datei.mandanten[eintrag.zeile],
        index: index,
      );
      if (vorschlaege.isNotEmpty) ergebnis[eintrag.zeile] = vorschlaege;
    }
    return ergebnis;
  }

  /// Die Vorschläge zu einer einzelnen Zeile. [index] wird einmal je Vorschau
  /// gebaut und über alle Zeilen wiederverwendet.
  ///
  /// Trägt die Zeile mehrere Kennzeichen, wird jedes gefragt: es ist das
  /// stärkste Signal, und der eingegrenzte Ausschnitt ist so klein, dass der
  /// zusätzliche Durchlauf nichts kostet. Doppelte Treffer fallen dabei
  /// zusammen, der erste Fund gewinnt — Kennzeichen vor Namensähnlichkeit.
  static List<MandantVorschlag> zuZeile({
    required ImportMandantEintrag zeile,
    required MandantenNamensindex index,
  }) {
    final nachname = ohneTitel(zeile.nachname);
    if (nachname.isEmpty) return const [];

    final kandidaten = index.kandidaten(
      nachname: nachname,
      kennzeichen: zeile.kennzeichen,
    );
    if (kandidaten.isEmpty) return const [];

    final gefunden = <int, MandantVorschlag>{};
    final kennzeichen = zeile.kennzeichen.isEmpty
        ? const ['']
        : zeile.kennzeichen;
    for (final zeichen in kennzeichen) {
      for (final vorschlag in MandantErkennung.finde(
        mandanten: kandidaten,
        vorname: zeile.vorname,
        nachname: nachname,
        kennzeichen: zeichen,
      )) {
        gefunden.putIfAbsent(vorschlag.mandant.id, () => vorschlag);
      }
    }

    final treffer = gefunden.values.toList();
    return treffer.length <= MandantErkennung.maxVorschlaege
        ? treffer
        : treffer.sublist(0, MandantErkennung.maxVorschlaege);
  }

  /// Der Nachname ohne die vorangestellten akademischen Grade. Das letzte Wort
  /// bleibt immer stehen: ein Eintrag, der nur aus einem Grad besteht, ist eine
  /// krumme Zeile — aber keine, die hier stillschweigend zu nichts wird.
  static String ohneTitel(String nachname) {
    final teile = nachname
        .trim()
        .split(RegExp(r'\s+'))
        .where((wort) => wort.isNotEmpty)
        .toList();
    if (teile.isEmpty) return '';

    var erstes = 0;
    while (erstes < teile.length - 1 && istTitelwort(teile[erstes])) {
      erstes++;
    }
    return teile.sublist(erstes).join(' ');
  }

  /// Ob [wort] ein akademischer Grad ist — Punkt und Schreibweise egal.
  static bool istTitelwort(String wort) => titelwoerter.contains(
    wort.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß]'), ''),
  );
}
