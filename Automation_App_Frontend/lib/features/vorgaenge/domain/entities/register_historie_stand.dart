import 'package:equatable/equatable.dart';

/// Was von **einem** Jahrgang übernommen ist (§6.2) — das Gegenstück zu
/// `JahrgangStandDto` im Backend.
///
/// [luecken] und [mitBefund] stehen hier, weil der Stand die einzige Stelle
/// ist, an der der Anwalt sie noch sieht: Nach dem Übernehmen ist der Bericht
/// des Imports weg, die offene Lücke bleibt.
class JahrgangStand extends Equatable {
  final int jahrgang;

  /// Übernommene Zeilen dieses Jahrgangs.
  final int zeilen;

  /// Die höchste vergebene laufende Nummer — die Messlatte für [luecken].
  final int hoechsteNummer;

  /// Fehlende Nummern zwischen 1 und [hoechsteNummer]. Sie sind die eine
  /// Fehlerklasse, die kein Erzeuger einer Importdatei an sich selbst bemerkt.
  final List<int> luecken;

  /// Zeilen mit mindestens einem Befund (Widerspruch, unbekanntes Kürzel).
  final int mitBefund;

  final DateTime? zuletztImportiertAm;

  const JahrgangStand({
    required this.jahrgang,
    this.zeilen = 0,
    this.hoechsteNummer = 0,
    this.luecken = const [],
    this.mitBefund = 0,
    this.zuletztImportiertAm,
  });

  /// Ob der Jahrgang lückenlos übernommen ist — das Häkchen an der Chip-Zeile.
  bool get vollstaendig => luecken.isEmpty;

  factory JahrgangStand.fromJson(Map<String, dynamic> json) {
    final zeitpunkt = json['zuletztImportiertAm'] as String?;
    return JahrgangStand(
      jahrgang: (json['jahrgang'] as num?)?.toInt() ?? 0,
      zeilen: (json['zeilen'] as num?)?.toInt() ?? 0,
      hoechsteNummer: (json['hoechsteNummer'] as num?)?.toInt() ?? 0,
      luecken: [
        for (final nummer in (json['luecken'] as List? ?? const []))
          (nummer as num).toInt(),
      ],
      mitBefund: (json['mitBefund'] as num?)?.toInt() ?? 0,
      // `toLocal()` wie überall an der Grenze zum Dienst: er sendet mit
      // Zeitzonenversatz, angezeigt wird Ortszeit.
      zuletztImportiertAm: zeitpunkt == null
          ? null
          : DateTime.tryParse(zeitpunkt)?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    jahrgang,
    zeilen,
    hoechsteNummer,
    luecken,
    mitBefund,
    zuletztImportiertAm,
  ];
}

/// Der Stand der Übernahme über alle Jahrgänge — die eine Stelle, an der
/// steht, was noch fehlt. Der Anwalt soll sehen, dass 2021 fehlt, *bevor* er
/// 2022 einliest.
///
/// **Kein festes Startjahr.** [fehlendeJahrgaenge] sind die Löcher *zwischen*
/// dem kleinsten und dem größten übernommenen Jahrgang: Wie weit das Register
/// der Kanzlei zurückreicht, sagt der Bestand und nicht eine Zahl im Code — und
/// ein Jahrgang vor dem ersten übernommenen fehlt nicht, er ist nur noch nicht
/// an der Reihe.
class RegisterHistorieStand extends Equatable {
  /// Die übernommenen Jahrgänge, aufsteigend.
  final List<JahrgangStand> jahrgaenge;

  final List<int> fehlendeJahrgaenge;

  const RegisterHistorieStand({
    this.jahrgaenge = const [],
    this.fehlendeJahrgaenge = const [],
  });

  /// Der Zustand vor dem ersten Abruf und nach einem Fehlschlag: nichts
  /// übernommen, nichts vermisst.
  static const RegisterHistorieStand leer = RegisterHistorieStand();

  bool get istLeer => jahrgaenge.isEmpty;

  /// Der älteste übernommene Jahrgang — der Untertitel „ab 2018". Null,
  /// solange nichts übernommen ist.
  int? get kleinsterJahrgang {
    if (jahrgaenge.isEmpty) return null;
    return jahrgaenge
        .map((stand) => stand.jahrgang)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Der jüngste übernommene Jahrgang. Null, solange nichts übernommen ist.
  int? get groesterJahrgang {
    if (jahrgaenge.isEmpty) return null;
    return jahrgaenge
        .map((stand) => stand.jahrgang)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Der Jahrgang, den die Anleitung vorschlagen soll: der kleinste fehlende,
  /// sonst das Jahr vor dem aktuellen. [jetzt] ist für Tests überschreibbar.
  int vorschlag({DateTime? jetzt}) {
    if (fehlendeJahrgaenge.isNotEmpty) {
      return fehlendeJahrgaenge.reduce((a, b) => a < b ? a : b);
    }
    return (jetzt ?? DateTime.now()).year - 1;
  }

  /// Der Stand zu einem Jahrgang, oder null, wenn er nicht übernommen ist.
  JahrgangStand? zuJahrgang(int jahrgang) {
    for (final stand in jahrgaenge) {
      if (stand.jahrgang == jahrgang) return stand;
    }
    return null;
  }

  factory RegisterHistorieStand.fromJson(Map<String, dynamic> json) =>
      RegisterHistorieStand(
        jahrgaenge: [
          for (final stand in (json['jahrgaenge'] as List? ?? const []))
            JahrgangStand.fromJson(stand as Map<String, dynamic>),
        ],
        fehlendeJahrgaenge: [
          for (final jahr in (json['fehlendeJahrgaenge'] as List? ?? const []))
            (jahr as num).toInt(),
        ],
      );

  @override
  List<Object?> get props => [jahrgaenge, fehlendeJahrgaenge];
}
