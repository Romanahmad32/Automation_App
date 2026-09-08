import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:equatable/equatable.dart';

/// Das Urteil des Dienstes über eine einzelne Zeile der Importdatei (§6.2).
///
/// [ImportArt] und [ImportSicherheit] kommen aus dem Mandantenimport und werden
/// hier bewusst **wiederverwendet**: Es sind dieselben drei Handlungen und
/// dieselben drei Stufen, und eine zweite Fassung der Wörter „sicher / unsicher
/// / sehr unsicher" liefe beim ersten neuen Wert auseinander. Aus dem Register
/// kommt nie `ergaenzt` — der Dienst kennt nur `neu`, `unveraendert` und
/// `abgelehnt`.
class RegisterZeilenBefund extends Equatable {
  /// Die Stelle in der Datei, 1-basiert innerhalb ihres Jahrgangs — der Bezug
  /// zurück auf die Zeile, die bearbeitet wird.
  final int zeile;

  final int jahrgang;
  final int laufendeNummer;
  final String aktenzeichen;

  /// „Mandant ./. Gegner" bzw. „Sachart Mandant" — die Spalte „Sache".
  final String anzeigetext;

  final String rechtsgebiet;
  final ImportSicherheit sicherheit;
  final ImportArt art;

  /// Was der Dienst an der Zeile gefunden hat, im Klartext: Widerspruch in
  /// Spalte 1, Abteilung gegen Rechtsgebiet, unbekanntes Kürzel, Doppelnummer.
  final List<String> befunde;

  /// Was schon der Erzeuger angemerkt hat — übernommen, nicht neu gedeutet.
  final List<String> hinweise;

  /// Die Zeile, zu der ein Mensch etwas zu sagen hat. Der Dienst rechnet sie
  /// aus (`Sicherheit != hoch || Befunde.Count > 0`) und schickt sie mit; hier
  /// wird sie **nicht** nachgerechnet, sonst gäbe es zwei Auslegungen derselben
  /// Regel.
  final bool zuPruefen;

  const RegisterZeilenBefund({
    this.zeile = 0,
    this.jahrgang = 0,
    this.laufendeNummer = 0,
    this.aktenzeichen = '',
    this.anzeigetext = '',
    this.rechtsgebiet = '',
    this.sicherheit = ImportSicherheit.unbekannt,
    this.art = ImportArt.neu,
    this.befunde = const [],
    this.hinweise = const [],
    this.zuPruefen = false,
  });

  /// Alles, was an dieser Zeile zu lesen ist: erst die Befunde des Dienstes,
  /// dann die Anmerkungen des Erzeugers.
  List<String> get alleMeldungen => [...befunde, ...hinweise];

  factory RegisterZeilenBefund.fromJson(Map<String, dynamic> json) =>
      RegisterZeilenBefund(
        zeile: json['zeile'] as int? ?? 0,
        jahrgang: json['jahrgang'] as int? ?? 0,
        laufendeNummer: json['laufendeNummer'] as int? ?? 0,
        aktenzeichen: json['aktenzeichen'] as String? ?? '',
        anzeigetext: json['anzeigetext'] as String? ?? '',
        rechtsgebiet: json['rechtsgebiet'] as String? ?? '',
        sicherheit: ImportSicherheit.ausWert(json['sicherheit'] as String?),
        art: ImportArt.ausWert(json['art'] as String?),
        befunde: texte(json['befunde']),
        hinweise: texte(json['hinweise']),
        zuPruefen: json['zuPruefen'] as bool? ?? false,
      );

  static List<String> texte(Object? wert) =>
      wert is List ? wert.whereType<String>().toList() : const [];

  @override
  List<Object?> get props => [
    zeile,
    jahrgang,
    laufendeNummer,
    aktenzeichen,
    anzeigetext,
    rechtsgebiet,
    sicherheit,
    art,
    befunde,
    hinweise,
    zuPruefen,
  ];
}
