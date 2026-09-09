import 'package:automation_app/features/register_import/domain/entities/register_import_zeile.dart';
import 'package:equatable/equatable.dart';

/// Ein Jahrgang des Word-Registers mit seinen Zeilen.
///
/// Der Jahrgang ist die natürliche Einheit dieser Übernahme: rund zweihundert
/// Zeilen, eine durchgehende Nummernfolge und damit eine Menge, die ein Mensch
/// wirklich prüfen kann. Tausende Zeilen auf einmal wären keine Prüfung mehr,
/// sondern nur der Beweis, dass keine stattgefunden hat.
class RegisterImportJahrgang extends Equatable {
  final int jahrgang;
  final List<RegisterImportZeile> zeilen;

  const RegisterImportJahrgang({
    required this.jahrgang,
    this.zeilen = const [],
  });

  /// Dieselbe Jahrgangsliste mit [zeilen] an Stelle der bisherigen.
  RegisterImportJahrgang mitZeilen(List<RegisterImportZeile> zeilen) =>
      RegisterImportJahrgang(jahrgang: jahrgang, zeilen: zeilen);

  factory RegisterImportJahrgang.fromJson(Map<String, dynamic> json) =>
      RegisterImportJahrgang(
        jahrgang: json['jahrgang'] as int? ?? 0,
        zeilen: RegisterImportDatei.zeilenAus(json['zeilen']),
      );

  Map<String, dynamic> toJson() => {
    'jahrgang': jahrgang,
    'zeilen': [for (final zeile in zeilen) zeile.toJson()],
  };

  @override
  List<Object?> get props => [jahrgang, zeilen];
}

/// Eine Importdatei mit einem oder mehreren Jahrgängen des Word-Registers
/// (§6.2). Beschrieben ist das Format in `docs/REGISTER_IMPORT.md`.
///
/// Der Anlass ist die Größenordnung: Das Register der Kanzlei ist ein
/// Word-Dokument mit rund neunzig Seiten. Es entsteht deshalb außerhalb dieser
/// App maschinell ein Auszug je Jahrgang, und die App prüft ihn, zeigt ihn und
/// schreibt erst nach Freigabe.
class RegisterImportDatei extends Equatable {
  /// Die einzige Fassung, die Frontend und Dienst lesen.
  static const aktuelleVersion = 1;

  final int version;
  final List<RegisterImportJahrgang> jahrgaenge;

  const RegisterImportDatei({
    this.version = aktuelleVersion,
    this.jahrgaenge = const [],
  });

  int get zeilenGesamt =>
      jahrgaenge.fold(0, (summe, jahr) => summe + jahr.zeilen.length);

  /// Dieselbe Datei, aber nur mit [jahrgang] darin — was „Übernehmen" an der
  /// Befundkarte eines einzelnen Jahrgangs abschickt. Kennt die Datei den
  /// Jahrgang nicht, bleibt die Liste leer und der Dienst hat nichts zu tun.
  RegisterImportDatei nurJahrgang(int jahrgang) => RegisterImportDatei(
    version: version,
    jahrgaenge: [
      for (final eintrag in jahrgaenge)
        if (eintrag.jahrgang == jahrgang) eintrag,
    ],
  );

  /// Dieselbe Datei mit [ersatz] an Stelle des gleichnamigen Jahrgangs.
  RegisterImportDatei mitJahrgang(RegisterImportJahrgang ersatz) =>
      RegisterImportDatei(
        version: version,
        jahrgaenge: [
          for (final eintrag in jahrgaenge)
            if (eintrag.jahrgang == ersatz.jahrgang) ersatz else eintrag,
        ],
      );

  /// Liest die **Langform** (`jahrgaenge`) und die **Kurzform** (`jahrgang`
  /// plus `zeilen` auf oberster Ebene, genau ein Jahrgang).
  ///
  /// Beide Formen zu lesen kostet zehn Zeilen und erspart dem Erzeuger die
  /// häufigste Stolperstelle: Wer einen einzelnen Jahrgang liefert, schreibt
  /// ihn erfahrungsgemäß flach hin. Geschrieben wird trotzdem immer die
  /// Langform ([toJson]) — eine Datei, zwei Schreibweisen sind für den Dienst
  /// zwei Fälle, und der zweite fällt erst auf, wenn er falsch ist.
  factory RegisterImportDatei.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? aktuelleVersion;
    final jahrgaenge = json['jahrgaenge'];
    if (jahrgaenge is List) {
      return RegisterImportDatei(
        version: version,
        jahrgaenge: [
          for (final eintrag in jahrgaenge.whereType<Map<String, dynamic>>())
            RegisterImportJahrgang.fromJson(eintrag),
        ],
      );
    }

    final jahrgang = json['jahrgang'];
    if (jahrgang is! int) return RegisterImportDatei(version: version);
    return RegisterImportDatei(
      version: version,
      jahrgaenge: [
        RegisterImportJahrgang(
          jahrgang: jahrgang,
          zeilen: zeilenAus(json['zeilen']),
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'jahrgaenge': [for (final jahr in jahrgaenge) jahr.toJson()],
  };

  static List<RegisterImportZeile> zeilenAus(Object? wert) => wert is List
      ? [
          for (final zeile in wert.whereType<Map<String, dynamic>>())
            RegisterImportZeile.fromJson(zeile),
        ]
      : const [];

  @override
  List<Object?> get props => [version, jahrgaenge];
}
