import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Stand der konfigurierten Standardpositionen (§4.4).
///
/// [positionen] ist nie leer im Sinne von „nichts anzeigbar": Bis zum ersten
/// erfolgreichen Laden steht die Vorgabe darin — der Wizard kann also immer
/// vorbelegen, auch wenn das Backend (noch) nicht geantwortet hat.
class StandardpositionenStand {
  final List<StandardSchadensposition> positionen;

  /// Erst nach einer erfolgreichen Backend-Antwort `true`. Solange es `false`
  /// ist, sind [positionen] der Rückfall aus dem Code.
  final bool geladen;

  final bool speichert;

  /// Übergangssignal für die Erfolgsmeldung des Editors — nur im Zustand
  /// direkt nach einem erfolgreichen Speichern `true`.
  final bool gespeichert;

  final String? meldung;

  const StandardpositionenStand({
    this.positionen = StandardSchadenspositionen.vorgabe,
    this.geladen = false,
    this.speichert = false,
    this.gespeichert = false,
    this.meldung,
  });

  StandardpositionenStand kopiereMit({
    List<StandardSchadensposition>? positionen,
    bool? geladen,
    bool? speichert,
    bool gespeichert = false,
    String? meldung,
  }) => StandardpositionenStand(
    positionen: positionen ?? this.positionen,
    geladen: geladen ?? this.geladen,
    speichert: speichert ?? this.speichert,
    gespeichert: gespeichert,
    meldung: meldung,
  );
}

/// Lädt und speichert die Standardpositionen. Ein Ladefehler ist kein harter
/// Fehler: Es bleibt bei der Vorgabe, die Meldung sagt es dem Editor.
@injectable
class StandardpositionenCubit extends Cubit<StandardpositionenStand> {
  final StandardSchadenspositionenRepository _repository;

  StandardpositionenCubit(this._repository)
    : super(const StandardpositionenStand());

  Future<void> laden() async {
    try {
      final positionen = await _repository.lade();
      emit(state.kopiereMit(positionen: positionen, geladen: true));
    } catch (_) {
      emit(
        state.kopiereMit(
          meldung: 'Die Standardpositionen konnten nicht geladen werden.',
        ),
      );
    }
  }

  Future<void> speichern(List<StandardSchadensposition> positionen) async {
    emit(state.kopiereMit(speichert: true));
    try {
      final gespeichert = await _repository.speichere(positionen);
      emit(
        state.kopiereMit(
          positionen: gespeichert,
          geladen: true,
          speichert: false,
          gespeichert: true,
        ),
      );
    } catch (_) {
      emit(
        state.kopiereMit(
          speichert: false,
          meldung: 'Die Standardpositionen konnten nicht gespeichert werden.',
        ),
      );
    }
  }

  /// Zurücksetzen = Speichern der leeren Liste: Das Backend löscht die
  /// Konfiguration und liefert wieder die fünf üblichen Positionen.
  Future<void> zuruecksetzen() => speichern(const []);
}
