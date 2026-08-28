import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der jüngste Versand je Vorgang (§4.7) — für die Vorgangsliste.
///
/// Ein Singleton und **ein** Abruf: Die Liste baut je Vorgang eine Zeile, und
/// jede davon einzeln nachfragen zu lassen hiesse, beim Blättern Dutzende
/// Anfragen zu stellen für eine Auskunft, die sich zwischendurch nicht ändert.
@lazySingleton
class LetzteVersaendeCubit extends Cubit<Map<String, VersandEintrag>> {
  final EmailVersandRepository _repository;

  bool _geladen = false;

  LetzteVersaendeCubit(this._repository) : super(const {});

  /// Holt den Stand, wenn er noch nicht da ist. Die Zeilen der Liste rufen das
  /// beim Aufgehen — die erste löst aus, die übrigen finden ihn vor.
  Future<void> ladenWennNoetig() async {
    if (_geladen) return;
    _geladen = true;
    await neuLaden();
  }

  /// Holt den Stand in jedem Fall — nach einem Versand ist der alte überholt.
  Future<void> neuLaden() async {
    try {
      final eintraege = await _repository.ladeLetzteVersaende();
      if (isClosed) return;
      emit({
        for (final eintrag in eintraege)
          eintrag.vorgangReferenz.toLowerCase(): eintrag,
      });
    } catch (_) {
      // Ohne Protokoll fehlt in der Liste eine Zeile. Das ist eine Auskunft
      // weniger, kein Grund, die Vorgangsverwaltung scheitern zu lassen.
    }
  }

  /// Der letzte Versand zu diesem Vorgang, oder null.
  VersandEintrag? zu(String referenz) => state[referenz.trim().toLowerCase()];
}
