import 'package:equatable/equatable.dart';

/// Der Zustand des Duplizierens (#104 Stufe 4). Er ist so kurzlebig wie die
/// Handlung: Nach [VorlagenKopieErfolg] bzw. [VorlagenKopieFehler] geht der
/// Cubit sofort wieder auf [VorlagenKopieRuht] — die Meldung ist damit ein
/// **Übergang**, den ein `BlocListener` genau einmal sieht, und kein Zustand,
/// den ein zweiter Aufbau der Seite noch einmal zeigt.
sealed class VorlagenKopieState extends Equatable {
  const VorlagenKopieState();

  @override
  List<Object?> get props => [];
}

final class VorlagenKopieRuht extends VorlagenKopieState {
  const VorlagenKopieRuht();
}

final class VorlagenKopieLaeuft extends VorlagenKopieState {
  const VorlagenKopieLaeuft();
}

final class VorlagenKopieErfolg extends VorlagenKopieState {
  /// Der Name, unter dem die Kopie angelegt wurde — er steht in der Meldung,
  /// weil er nicht der Name ist, den der Anwalt angeklickt hat.
  final String name;

  const VorlagenKopieErfolg(this.name);

  @override
  List<Object?> get props => [name];
}

final class VorlagenKopieFehler extends VorlagenKopieState {
  final String meldung;

  const VorlagenKopieFehler(this.meldung);

  @override
  List<Object?> get props => [meldung];
}
