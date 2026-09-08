import 'package:automation_app/features/register_import/domain/entities/register_zeilen_befund.dart';
import 'package:equatable/equatable.dart';

/// Was ein Jahrgang der Importdatei bewirkt oder bewirken würde (§6.2).
///
/// Die vier Zahlen, die niemand aus der Datei ablesen kann, stehen hier:
/// [luecken], [doppelte], [abweichungen] und [zuPruefen]. Die Lücken sind
/// dabei die wichtigste — eine fehlende laufende Nummer ist der einzige Beleg
/// dafür, dass dem Erzeuger eine Zeile abhandengekommen ist, und er bemerkt es
/// nie an sich selbst.
class JahrgangBefund extends Equatable {
  final int jahrgang;

  /// Zeilen dieses Jahrgangs in der Datei.
  final int zeilen;

  /// Die fehlenden Nummern zwischen 1 und der höchsten Nummer des Jahrgangs —
  /// gemessen an Datei **und** Bestand zusammen.
  final List<int> luecken;

  /// Nummern, die in der Datei mehrfach vorkommen.
  final List<int> doppelte;

  final int neu;
  final int unveraendert;

  /// Abgelehnt wird nur eine echte Doppelnummer. Inhaltliche Befunde — Spalte
  /// 1, Abteilung gegen Rechtsgebiet, Katalog, Tippfehler — lehnen nie eine
  /// Zeile ab: Sie wird gespeichert wie im Originalregister und trägt den
  /// Befund.
  final int abgelehnt;

  final int zuPruefen;

  /// Zeilen, deren Abteilung nicht zum Rechtsgebiet in Spalte 3 passt.
  final int abweichungen;

  final List<RegisterZeilenBefund> eintraege;

  const JahrgangBefund({
    this.jahrgang = 0,
    this.zeilen = 0,
    this.luecken = const [],
    this.doppelte = const [],
    this.neu = 0,
    this.unveraendert = 0,
    this.abgelehnt = 0,
    this.zuPruefen = 0,
    this.abweichungen = 0,
    this.eintraege = const [],
  });

  /// Ändert dieser Jahrgang überhaupt etwas? Sonst wäre „Übernehmen" ein Knopf
  /// ohne Wirkung.
  bool get bewirktEtwas => neu > 0;

  /// Die Zeilen, die der Filter „nur zu prüfen" übrig lässt.
  List<RegisterZeilenBefund> sichtbar({required bool nurZuPruefen}) =>
      nurZuPruefen
      ? [
          for (final eintrag in eintraege)
            if (eintrag.zuPruefen) eintrag,
        ]
      : eintraege;

  factory JahrgangBefund.fromJson(Map<String, dynamic> json) {
    final eintraege = json['eintraege'];
    return JahrgangBefund(
      jahrgang: json['jahrgang'] as int? ?? 0,
      zeilen: json['zeilen'] as int? ?? 0,
      luecken: zahlen(json['luecken']),
      doppelte: zahlen(json['doppelte']),
      neu: json['neu'] as int? ?? 0,
      unveraendert: json['unveraendert'] as int? ?? 0,
      abgelehnt: json['abgelehnt'] as int? ?? 0,
      zuPruefen: json['zuPruefen'] as int? ?? 0,
      abweichungen: json['abweichungen'] as int? ?? 0,
      eintraege: eintraege is List
          ? [
              for (final eintrag in eintraege.whereType<Map<String, dynamic>>())
                RegisterZeilenBefund.fromJson(eintrag),
            ]
          : const [],
    );
  }

  static List<int> zahlen(Object? wert) =>
      wert is List ? wert.whereType<int>().toList() : const [];

  @override
  List<Object?> get props => [
    jahrgang,
    zeilen,
    luecken,
    doppelte,
    neu,
    unveraendert,
    abgelehnt,
    zuPruefen,
    abweichungen,
    eintraege,
  ];
}

/// Was der Registerimport bewirkt hat oder bewirken würde. Vorschau und
/// Übernahme liefern denselben Bericht; nur [angewendet] unterscheidet sie —
/// die Vorschau zeigt damit garantiert das, was die Übernahme tut.
class RegisterImportBericht extends Equatable {
  final List<JahrgangBefund> jahrgaenge;
  final bool angewendet;

  const RegisterImportBericht({
    this.jahrgaenge = const [],
    this.angewendet = false,
  });

  int get zeilenGesamt =>
      jahrgaenge.fold(0, (summe, jahr) => summe + jahr.zeilen);

  int get zuPruefenGesamt =>
      jahrgaenge.fold(0, (summe, jahr) => summe + jahr.zuPruefen);

  bool get bewirktEtwas => jahrgaenge.any((jahr) => jahr.bewirktEtwas);

  /// Der Bericht mit [ersatz] an Stelle des gleichnamigen Jahrgangs — was nach
  /// der Übernahme eines einzelnen Jahrgangs entsteht. Die übrigen Karten
  /// bleiben stehen, statt hinter dem Ergebnis eines einzigen zu verschwinden.
  RegisterImportBericht mitJahrgang(
    JahrgangBefund ersatz, {
    required bool angewendet,
  }) => RegisterImportBericht(
    jahrgaenge: [
      for (final jahr in jahrgaenge)
        if (jahr.jahrgang == ersatz.jahrgang) ersatz else jahr,
    ],
    angewendet: angewendet,
  );

  factory RegisterImportBericht.fromJson(Map<String, dynamic> json) {
    final jahrgaenge = json['jahrgaenge'];
    return RegisterImportBericht(
      jahrgaenge: jahrgaenge is List
          ? [
              for (final jahr in jahrgaenge.whereType<Map<String, dynamic>>())
                JahrgangBefund.fromJson(jahr),
            ]
          : const [],
      angewendet: json['angewendet'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [jahrgaenge, angewendet];
}
