part of 'ablage_cubit.dart';

/// [konflikt]: im Fall-Ordner liegt bereits eine gleichnamige Datei; die
/// Ablage wartet auf die Entscheidung des Anwalts (siehe [AblageStrategie]).
enum AblageStatus { initial, loading, ready, filing, konflikt, erfolg, fehler }

class AblageState extends Equatable {
  final AblageStatus status;

  /// Stammordner aus den Einstellungen; leer = nicht gesetzt.
  final String stammordner;

  final List<Mandant> mandanten;
  final List<Akte> akten;

  /// Die in der Akte abgelegten Dateien, in der Reihenfolge der Ablage — je
  /// nach gewähltem Format die Word-Fassung, die PDF-Fassung oder beide. Vor
  /// dem Erfolg leer.
  final List<String> zielpfade;

  /// Bei [AblageStatus.konflikt] der Pfad der bereits vorhandenen Datei, über
  /// die der Anwalt gerade entscheidet; sonst null.
  final String? konfliktPfad;

  /// Fehlermeldung.
  final String? message;

  const AblageState({
    this.status = AblageStatus.initial,
    this.stammordner = '',
    this.mandanten = const [],
    this.akten = const [],
    this.zielpfade = const [],
    this.konfliktPfad,
    this.message,
  });

  bool get stammordnerGesetzt => stammordner.trim().isNotEmpty;

  AblageState copyWith({
    AblageStatus? status,
    String? stammordner,
    List<Mandant>? mandanten,
    List<Akte>? akten,
    List<String>? zielpfade,
    String? Function()? konfliktPfad,
    String? Function()? message,
  }) {
    return AblageState(
      status: status ?? this.status,
      stammordner: stammordner ?? this.stammordner,
      mandanten: mandanten ?? this.mandanten,
      akten: akten ?? this.akten,
      zielpfade: zielpfade ?? this.zielpfade,
      konfliktPfad: konfliktPfad != null ? konfliktPfad() : this.konfliktPfad,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    stammordner,
    mandanten,
    akten,
    zielpfade,
    konfliktPfad,
    message,
  ];
}
