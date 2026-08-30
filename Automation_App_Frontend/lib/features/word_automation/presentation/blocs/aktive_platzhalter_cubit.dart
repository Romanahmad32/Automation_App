import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Was über die Platzhalter der gerade geladenen Word-Datei bekannt ist.
///
/// [platzhalter] null heißt: (noch) nichts — dann sperrt das Formular keine
/// Pflichtfelder (#35 Teil 2). Nach einem Fehler bleibt es bei null;
/// [fehlgeschlagen] unterscheidet den Fehler vom laufenden Laden, damit das
/// Formular nicht ewig auf ein Ergebnis wartet, das nie kommt.
class AktivePlatzhalterStand extends Equatable {
  /// Pfad der Word-Datei, zu der dieser Stand gehört — der Leser prüft ihn
  /// gegen seine eigene Datei, sonst gälte nach einem Variantenwechsel kurz
  /// der Stand der vorigen Datei.
  final String? pfad;

  final Set<String>? platzhalter;
  final bool fehlgeschlagen;

  const AktivePlatzhalterStand({
    this.pfad,
    this.platzhalter,
    this.fehlgeschlagen = false,
  });

  @override
  List<Object?> get props => [pfad, platzhalter, fehlgeschlagen];
}

/// Liest die {{Platzhalter}} der aktiven Word-Datei (je gewählter Variante
/// ohne/mit Auflistung), damit das Ausfüllformular die Pflicht daraus ableiten
/// kann statt sie global zu speichern (#35 Teil 2).
@injectable
class AktivePlatzhalterCubit extends Cubit<AktivePlatzhalterStand> {
  final UseCase<List<String>, GetTemplatePlaceholdersParams>
  _getTemplatePlaceholders;

  AktivePlatzhalterCubit(this._getTemplatePlaceholders)
    : super(const AktivePlatzhalterStand());

  /// Lädt die Platzhalter zu [wordDateiPfad]. Während des Ladens ist der
  /// Stand „nichts bekannt" für genau diese Datei.
  Future<void> lade(String wordDateiPfad) async {
    emit(AktivePlatzhalterStand(pfad: wordDateiPfad));
    final result = await _getTemplatePlaceholders(
      GetTemplatePlaceholdersParams(wordDateiPfad),
    );
    // Antwort einer inzwischen abgewählten Datei verwerfen — sonst stünde
    // nach schnellem Hin- und Herschalten der falsche Bestand im Formular.
    if (isClosed || state.pfad != wordDateiPfad) return;
    switch (result) {
      case Right(value: final platzhalter):
        emit(
          AktivePlatzhalterStand(
            pfad: wordDateiPfad,
            platzhalter: platzhalter.toSet(),
          ),
        );
      case Left():
        emit(AktivePlatzhalterStand(pfad: wordDateiPfad, fehlgeschlagen: true));
    }
  }
}
