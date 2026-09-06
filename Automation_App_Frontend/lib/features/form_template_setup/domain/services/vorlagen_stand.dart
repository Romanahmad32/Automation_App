import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';

/// Ergebnis der Rechnung „Was fehlt dieser Vorlage noch?" — **eine** Rechnung
/// über **beide** Word-Dateien (#104).
///
/// Bis hierher zählten zwei Dienste dieselbe Sache aus zwei Richtungen und je
/// Datei getrennt: [PlatzhalterUebernahme.uebernehmbare] (Platzhalter ohne
/// Feld) und [FeldVorkommen] (Feld ohne Platzhalter). Wer beide Slots
/// nacheinander fragte, zählte einen Platzhalter, der in beiden Dateien steht,
/// zweimal — und bekam nie eine Aussage über die Vorlage als Ganzes. Diese
/// Klasse rechnet einmal und liefert beide Richtungen zusammen.
///
/// Die Regeln dahinter (vom Anwender festgelegt):
///
/// * Die beiden Dateien sind **gleichwertig**. Eine Vorlage darf nur eine von
///   beiden haben; keine ist „die zweite" oder optional.
/// * **Unvollständig** ist eine Vorlage genau dann, wenn sie keine Datei hat
///   oder mindestens ein Platzhalter ohne Feld dasteht — der bliebe beim
///   Erzeugen roh als `{{…}}` im Brief stehen.
/// * Ein **Feld ohne Vorkommen** ist nur eine Warnung: Es bleibt wirkungslos,
///   aber das Dokument sieht deswegen nicht falsch aus.
/// * App-eigene Platzhalter ([PlatzhalterUebernahme] filtert sie) sind nie
///   offen — die füllt das Backend beim Erzeugen selbst.
class VorlagenStand {
  const VorlagenStand({
    required this.platzhalterOhneFeld,
    required this.felderOhneVorkommen,
    required this.hatDateiOhne,
    required this.hatDateiMit,
    required this.platzhalterUnbekannt,
  });

  /// Platzhalter beider Dateien, zu denen kein Feld gehört. Dokumentreihenfolge
  /// (erst ohne, dann mit Auflistung), ohne Doppelte, ohne app-eigene.
  final List<String> platzhalterOhneFeld;

  /// Feldnamen, deren Platzhalter in keiner (bekannten) Datei vorkommt — in der
  /// Reihenfolge der Felder, jeder Name nur einmal, ohne Randleerzeichen.
  final List<String> felderOhneVorkommen;

  final bool hatDateiOhne;
  final bool hatDateiMit;

  /// true, wenn mindestens eine vorhandene Datei keine bekannte
  /// Platzhalterliste hat (noch nicht geladen oder Lesefehler). Dann ist jede
  /// Aussage hier nur die halbe Wahrheit — deshalb steht sie auch in
  /// [zusammenfassung].
  final bool platzhalterUnbekannt;

  bool get hatDatei => hatDateiOhne || hatDateiMit;

  bool get istVollstaendig => hatDatei && platzhalterOhneFeld.isEmpty;

  bool get hatWarnungen => felderOhneVorkommen.isNotEmpty;

  /// Zahl der „offenen" Einträge für den Filter „Nur offene" — beide
  /// Richtungen zusammen.
  int get anzahlOffen =>
      platzhalterOhneFeld.length + felderOhneVorkommen.length;

  /// [platzhalterOhne]/[platzhalterMit]: null = Datei nicht vorhanden **oder**
  /// Liste unbekannt — deshalb [hatDateiOhne]/[hatDateiMit] getrennt
  /// übergeben. Erst beides zusammen unterscheidet „es gibt nichts zu lesen"
  /// von „noch nicht gelesen".
  ///
  /// [feldnamen]: die **aufgelösten** Feldnamen, nicht die Control-Schlüssel
  /// (`field_0`, `field_1`, … — solange die Detailseite offen ist, steht der
  /// Name im Wert des Controls, siehe FEATURE.md). null- und Leereinträge
  /// werden übergangen: ein frisch angelegtes, noch namenloses Feld ist kein
  /// Mangel.
  static VorlagenStand bestimme({
    required bool hatDateiOhne,
    required bool hatDateiMit,
    required List<String>? platzhalterOhne,
    required List<String>? platzhalterMit,
    required Iterable<String?> feldnamen,
  }) {
    final unbekannt =
        (hatDateiOhne && platzhalterOhne == null) ||
        (hatDateiMit && platzhalterMit == null);

    // Beide Listen in einem Aufruf: uebernehmbare entdoppelt über die Grenze
    // der Dateien hinweg und wirft die app-eigenen weg — genau die Rechnung,
    // die je Slot getrennt doppelt zählte.
    final offen = PlatzhalterUebernahme.uebernehmbare([
      ...?platzhalterOhne,
      ...?platzhalterMit,
    ], feldnamen);

    return VorlagenStand(
      platzhalterOhneFeld: offen,
      // Fehlt zu einer vorhandenen Datei die Platzhalterliste, kann über die
      // Felder niemand etwas sagen — Rückfall wie VerwendeteFelder
      // .wirdVerwendet: im Zweifel nichts anmahnen statt falsch anmahnen.
      felderOhneVorkommen: unbekannt
          ? const []
          : _ohneVorkommen(feldnamen, platzhalterOhne, platzhalterMit),
      hatDateiOhne: hatDateiOhne,
      hatDateiMit: hatDateiMit,
      platzhalterUnbekannt: unbekannt,
    );
  }

  /// Was der Vorlage fehlt, als Satzstück — null heißt: nichts.
  ///
  /// Genau dann gesetzt, wenn [istVollstaendig] false ist; die fehlende Datei
  /// steht vor der Platzhalterzahl, denn ohne Datei sagt die Zahl nichts.
  String? get mangelText {
    if (!hatDatei) return 'Keine Word-Datei verknüpft';
    if (platzhalterOhneFeld.isEmpty) return null;
    final anzahl = platzhalterOhneFeld.length;
    return anzahl == 1
        ? '1 Platzhalter ohne Feld'
        : '$anzahl Platzhalter ohne Feld';
  }

  /// Die Warnung (Felder, die ins Leere laufen) als Satzstück — null heißt:
  /// keine. Sie steht getrennt, damit ein Widget sie anders färben kann als
  /// den Mangel: Sie hält die Vorlage nicht auf.
  String? get warnungText {
    if (felderOhneVorkommen.isEmpty) return null;
    final anzahl = felderOhneVorkommen.length;
    return anzahl == 1
        ? '1 Feld in keiner Datei (Warnung)'
        : '$anzahl Felder in keiner Datei (Warnung)';
  }

  /// Der Vorbehalt zu [platzhalterUnbekannt] als Satzstück — null heißt: alles
  /// Vorhandene ist gelesen.
  String? get unbekanntText =>
      platzhalterUnbekannt ? 'Platzhalter noch nicht gelesen' : null;

  /// Der ganze Stand in einer Zeile, für den Stand-Block über der Vorlage —
  /// „Vollständig", „3 Platzhalter ohne Feld · 2 Felder in keiner Datei
  /// (Warnung)", „Keine Word-Datei verknüpft".
  String get zusammenfassung =>
      [mangelText ?? 'Vollständig', ?warnungText, ?unbekanntText].join(' · ');

  static List<String> _ohneVorkommen(
    Iterable<String?> feldnamen,
    List<String>? platzhalterOhne,
    List<String>? platzhalterMit,
  ) {
    final ohne = platzhalterOhne?.toSet();
    final mit = platzhalterMit?.toSet();
    final gesehen = <String>{};
    final ergebnis = <String>[];
    for (final name in feldnamen) {
      // FeldVorkommen ist hier der Maßstab: derselbe Vergleich ohne
      // Groß-/Kleinschreibung wie die Ersetzung im Backend, dieselbe Antwort
      // „nichts zu sagen" (null) bei leerem Namen oder ohne jede bekannte
      // Platzhaltermenge.
      final vorkommen = FeldVorkommen.bestimme(
        name,
        ohneAuflistung: ohne,
        mitAuflistung: mit,
      );
      if (vorkommen != FeldVorkommen.inKeinerDatei) continue;
      final sauber = name!.trim();
      // Zwei Felder gleichen Namens sind für sich schon ein Fehler; sie hier
      // zweimal zu melden verdoppelte nur die Zahl im Filter „Nur offene".
      if (!gesehen.add(sauber.toLowerCase())) continue;
      ergebnis.add(sauber);
    }
    return ergebnis;
  }
}
