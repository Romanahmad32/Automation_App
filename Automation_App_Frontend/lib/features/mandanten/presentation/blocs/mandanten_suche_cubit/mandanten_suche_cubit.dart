import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_mandanten_seite.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'mandanten_suche_state.dart';

/// Sucht einen Mandanten im **ganzen** Register — für den Zuordnen-Dialog.
///
/// Er hängt bewusst nicht am Zustand des `MandantenOverviewBloc`: dessen
/// Mandantenliste ist seit dem seitenweisen Laden nur der geholte Ausschnitt,
/// und ein Dialog, der darin sucht, fände den gesuchten Mandanten je nach
/// Scrollstand mal und mal nicht. Gezeigt werden höchstens [hoechstens]
/// Treffer; im Dialog ist ohnehin nur Platz für eine Handvoll Zeilen, und wer
/// mehr trifft, sucht weiter statt zu blättern.
@injectable
class MandantenSucheCubit extends Cubit<MandantenSucheState> {
  /// So viele Treffer zeigt der Dialog.
  static const int hoechstens = 20;

  /// Wie lange das Suchfeld wartet, bevor es hier ankommt. Die Wartezeit
  /// selbst sitzt im `EntitySearchBar` — sonst wäre „Mustermann" zehn Abrufe
  /// für ein Ergebnis.
  static const Duration verzoegerung = Duration(milliseconds: 250);

  final UseCase<MandantenSeite, MandantenSeiteParams> _getMandantenSeite;

  MandantenSucheCubit(this._getMandantenSeite)
    : super(const MandantenSucheState());

  /// Sucht nach [query].
  Future<void> suche(String query) {
    emit(state.copyWith(query: query, laedt: true, fehlerVerwerfen: true));
    return _hole(query);
  }

  /// Der erste Abruf beim Öffnen des Dialogs.
  Future<void> laden() {
    emit(state.copyWith(laedt: true, fehlerVerwerfen: true));
    return _hole(state.query);
  }

  Future<void> _hole(String query) async {
    final result = await _getMandantenSeite(
      MandantenSeiteParams(suche: query, anzahl: hoechstens),
    );
    if (isClosed || state.query != query) return;
    switch (result) {
      case Right(value: final seite):
        emit(
          state.copyWith(
            treffer: seite.mandanten,
            gefunden: seite.gefiltert,
            laedt: false,
          ),
        );
      case Left(value: final failure):
        emit(
          state.copyWith(
            treffer: const [],
            gefunden: 0,
            laedt: false,
            fehler: failure.message,
          ),
        );
    }
  }
}
