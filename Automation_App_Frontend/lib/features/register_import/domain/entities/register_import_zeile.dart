import 'package:equatable/equatable.dart';

/// Eine Zeile des Word-Registers, so wie der Erzeuger der Importdatei sie
/// gelesen hat (§6.2). Beschrieben ist das Format in `docs/REGISTER_IMPORT.md`;
/// diese Klasse ist dessen Dart-Seite.
///
/// Gelesen wird nachsichtig: fehlende Felder sind leer, unbekannte werden
/// übergangen. Der Erzeuger ist ein Programm, kein Formular, und ein Jahrgang
/// mit zweihundert brauchbaren und einer krummen Zeile darf nicht als Ganzes
/// scheitern.
///
/// **Nichts wird hier still berichtigt.** Ein Widerspruch zwischen Spalte 1 und
/// dem Aktenzeichen, eine Abteilung, die nicht zum Rechtsgebiet passt, ein
/// erkennbarer Tippfehler — all das steht so in der Zeile, wie es im
/// Originalregister steht, und wird vom Dienst als Befund gemeldet. Wer es hier
/// glättete, verlöre die Information und behielte nur noch den geglätteten
/// Fehler.
class RegisterImportZeile extends Equatable {
  /// Die laufende Nummer des Jahrgangs — die Vollständigkeitsprobe. Sie läuft
  /// je Jahr lückenlos von 1 aufwärts; eine fehlende Nummer ist die eine
  /// Fehlerklasse, die kein Erzeuger an sich selbst bemerkt.
  final int laufendeNummer;

  /// Ein Zusatz hinter der Nummer, etwa `-I` in `10/19-I`.
  final String nummerZusatz;

  /// Was in Spalte 1 des Word-Registers stand. Sie wiederholt die Nummer aus
  /// dem Aktenzeichen; weichen beide voneinander ab, ist die Zeile falsch
  /// zerlegt worden.
  final String spalte1;

  final String aktenzeichen;

  /// Das normalisierte Abteilungskürzel (`C 03o` → `C03o`).
  final String abteilung;

  /// Dasselbe Kürzel in der Schreibweise der Vorlage — der Beleg dafür, dass
  /// nicht geraten wurde.
  final String abteilungRoh;

  /// Die Sachart bei Form B („Bußgeldsache", „Strafsache", „Familiensache").
  final String sachart;

  final String mandant;
  final String gegner;
  final String sachbestand;
  final String unfalldatum;
  final String rechtsgebiet;

  /// Die Zelle des Word-Registers im Wortlaut — der Beleg, an dem sich jede
  /// Deutung nachprüfen lässt.
  final String freitext;

  /// Selbsteinschätzung des Erzeugers: `hoch`, `mittel`, `niedrig`.
  final String sicherheit;

  /// Was dem Erzeuger an dieser Zeile aufgefallen ist, im Klartext.
  final List<String> hinweise;

  /// Von Hand nachbearbeitet, bevor die Datei übernommen wurde.
  ///
  /// Steht **nicht** im Dateiformat und geht auch nicht über die Leitung: die
  /// Angabe gilt dem laufenden Vorgang, nicht dem Bestand. Sie hängt trotzdem
  /// an der Zeile und nicht an einer Nummer daneben — Zeilen verschieben sich,
  /// sobald eine weggelassen wird, und eine Merkliste aus Indizes wäre danach
  /// still falsch.
  final bool bearbeitet;

  const RegisterImportZeile({
    this.laufendeNummer = 0,
    this.nummerZusatz = '',
    this.spalte1 = '',
    this.aktenzeichen = '',
    this.abteilung = '',
    this.abteilungRoh = '',
    this.sachart = '',
    this.mandant = '',
    this.gegner = '',
    this.sachbestand = '',
    this.unfalldatum = '',
    this.rechtsgebiet = '',
    this.freitext = '',
    this.sicherheit = '',
    this.hinweise = const [],
    this.bearbeitet = false,
  });

  RegisterImportZeile copyWith({
    int? laufendeNummer,
    String? nummerZusatz,
    String? spalte1,
    String? aktenzeichen,
    String? abteilung,
    String? abteilungRoh,
    String? sachart,
    String? mandant,
    String? gegner,
    String? sachbestand,
    String? unfalldatum,
    String? rechtsgebiet,
    String? freitext,
    String? sicherheit,
    List<String>? hinweise,
    bool? bearbeitet,
  }) => RegisterImportZeile(
    laufendeNummer: laufendeNummer ?? this.laufendeNummer,
    nummerZusatz: nummerZusatz ?? this.nummerZusatz,
    spalte1: spalte1 ?? this.spalte1,
    aktenzeichen: aktenzeichen ?? this.aktenzeichen,
    abteilung: abteilung ?? this.abteilung,
    abteilungRoh: abteilungRoh ?? this.abteilungRoh,
    sachart: sachart ?? this.sachart,
    mandant: mandant ?? this.mandant,
    gegner: gegner ?? this.gegner,
    sachbestand: sachbestand ?? this.sachbestand,
    unfalldatum: unfalldatum ?? this.unfalldatum,
    rechtsgebiet: rechtsgebiet ?? this.rechtsgebiet,
    freitext: freitext ?? this.freitext,
    sicherheit: sicherheit ?? this.sicherheit,
    hinweise: hinweise ?? this.hinweise,
    bearbeitet: bearbeitet ?? this.bearbeitet,
  );

  factory RegisterImportZeile.fromJson(Map<String, dynamic> json) {
    final hinweise = json['hinweise'];
    return RegisterImportZeile(
      laufendeNummer: json['laufendeNummer'] as int? ?? 0,
      nummerZusatz: json['nummerZusatz'] as String? ?? '',
      spalte1: json['spalte1'] as String? ?? '',
      aktenzeichen: json['aktenzeichen'] as String? ?? '',
      abteilung: json['abteilung'] as String? ?? '',
      abteilungRoh: json['abteilungRoh'] as String? ?? '',
      sachart: json['sachart'] as String? ?? '',
      mandant: json['mandant'] as String? ?? '',
      gegner: json['gegner'] as String? ?? '',
      sachbestand: json['sachbestand'] as String? ?? '',
      unfalldatum: json['unfalldatum'] as String? ?? '',
      rechtsgebiet: json['rechtsgebiet'] as String? ?? '',
      freitext: json['freitext'] as String? ?? '',
      sicherheit: json['sicherheit'] as String? ?? '',
      hinweise: hinweise is List
          ? hinweise.whereType<String>().toList()
          : const [],
    );
  }

  /// [bearbeitet] fehlt mit Absicht: Das Backend fängt damit nichts an, und ein
  /// Feld im Vertrag, das niemand liest, ist eine Zusage ohne Gegenstand.
  Map<String, dynamic> toJson() => {
    'laufendeNummer': laufendeNummer,
    'nummerZusatz': nummerZusatz,
    'spalte1': spalte1,
    'aktenzeichen': aktenzeichen,
    'abteilung': abteilung,
    'abteilungRoh': abteilungRoh,
    'sachart': sachart,
    'mandant': mandant,
    'gegner': gegner,
    'sachbestand': sachbestand,
    'unfalldatum': unfalldatum,
    'rechtsgebiet': rechtsgebiet,
    'freitext': freitext,
    'sicherheit': sicherheit,
    'hinweise': hinweise,
  };

  @override
  List<Object?> get props => [
    laufendeNummer,
    nummerZusatz,
    spalte1,
    aktenzeichen,
    abteilung,
    abteilungRoh,
    sachart,
    mandant,
    gegner,
    sachbestand,
    unfalldatum,
    rechtsgebiet,
    freitext,
    sicherheit,
    hinweise,
    bearbeitet,
  ];
}
