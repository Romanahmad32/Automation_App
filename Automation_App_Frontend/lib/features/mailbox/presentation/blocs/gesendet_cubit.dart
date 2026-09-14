import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Bereich „Gesendet" des Postfachs (§4.3): alles, was aus der App
/// hinausging, über **alle** Vorgänge hinweg und chronologisch — die Antwort
/// auf „Was ist heute rausgegangen?".
///
/// Eigener Cubit neben `LetzteVersaendeCubit`: Der liefert je Vorgang **eine**
/// Zeile (den jüngsten Versand) für die Vorgangsliste und ist ein Singleton,
/// weil ihn dort Dutzende Zeilen zugleich fragen. Hier wird die umgekehrte
/// Frage gestellt — jeder einzelne Versand, gedeckelt bei [limit] —, und die
/// Antwort gehört nicht in denselben Zustand: Ein gemeinsamer Cubit müsste
/// beide Sichten halten und bei jedem Abruf entscheiden, welche gerade gemeint
/// ist.
@injectable
class GesendetCubit extends Cubit<GesendetState> {
  final EmailVersandRepository _repository;

  GesendetCubit(this._repository) : super(const GesendetState());

  /// Holt den Stand. [limit] deckelt, wie weit zurück gelesen wird — der
  /// Dienst begrenzt zusätzlich; der Bereich ist ein Blick auf die jüngste
  /// Post, kein Archiv.
  Future<void> laden({int limit = 200}) async {
    emit(const GesendetState(laedt: true));
    try {
      final eintraege = await _repository.ladeAlleVersaende(limit: limit);
      if (isClosed) return;
      emit(GesendetState(eintraege: eintraege));
    } catch (_) {
      if (isClosed) return;
      // Der Wortlaut nennt die Ursache nicht: Sie steht im Protokoll des
      // Dienstes, und dem Anwalt hilft hier nur, dass es einen zweiten
      // Versuch gibt.
      emit(
        const GesendetState(
          fehler:
              'Die versendeten Nachrichten konnten nicht geladen werden. '
              'Bitte erneut versuchen.',
        ),
      );
    }
  }
}

/// Zustand des Gesendet-Bereichs. Bewusst ohne `copyWith`: Die drei Fälle
/// (lädt, geladen, fehlgeschlagen) schließen einander aus, und jeder Abruf
/// beginnt von vorn.
class GesendetState {
  /// Die Versände, das Jüngste zuerst — so, wie der Dienst sie liefert.
  final List<VersandEintrag> eintraege;

  final bool laedt;
  final String? fehler;

  const GesendetState({
    this.eintraege = const [],
    this.laedt = false,
    this.fehler,
  });
}
