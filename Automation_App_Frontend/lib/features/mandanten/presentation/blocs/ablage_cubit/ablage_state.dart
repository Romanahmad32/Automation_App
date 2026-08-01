part of 'ablage_cubit.dart';

enum AblageStatus { initial, loading, ready, filing, erfolg, fehler }

class AblageState extends Equatable {
  final AblageStatus status;

  /// Stammordner aus den Einstellungen; leer = nicht gesetzt.
  final String stammordner;

  final List<Mandant> mandanten;
  final List<Akte> akten;

  /// Zielpfad der abgelegten Kopie nach Erfolg.
  final String? zielpfad;

  /// Fehlermeldung.
  final String? message;

  const AblageState({
    this.status = AblageStatus.initial,
    this.stammordner = '',
    this.mandanten = const [],
    this.akten = const [],
    this.zielpfad,
    this.message,
  });

  bool get stammordnerGesetzt => stammordner.trim().isNotEmpty;

  AblageState copyWith({
    AblageStatus? status,
    String? stammordner,
    List<Mandant>? mandanten,
    List<Akte>? akten,
    String? Function()? zielpfad,
    String? Function()? message,
  }) {
    return AblageState(
      status: status ?? this.status,
      stammordner: stammordner ?? this.stammordner,
      mandanten: mandanten ?? this.mandanten,
      akten: akten ?? this.akten,
      zielpfad: zielpfad != null ? zielpfad() : this.zielpfad,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    stammordner,
    mandanten,
    akten,
    zielpfad,
    message,
  ];
}
