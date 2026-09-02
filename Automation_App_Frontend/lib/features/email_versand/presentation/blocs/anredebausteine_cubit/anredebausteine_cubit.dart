import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Bestand der Anredeanfänge (§4.7, §7.1) — gepflegt in den Einstellungen,
/// gewählt im Versanddialog.
///
/// Ein Singleton aus demselben Grund wie `GrussformelnCubit`: Beide Seiten
/// meinen denselben Bestand, und wer eine Anrede anlegt und danach schreibt,
/// soll sie vorfinden.
@lazySingleton
class AnredebausteineCubit extends Cubit<AnredebausteineState> {
  final AnredebausteineRepository _repository;

  /// Der laufende Abruf — Verwaltung und Versanddialog fragen beide beim
  /// Aufgehen.
  Future<void>? _laeuft;

  AnredebausteineCubit(this._repository) : super(const AnredebausteineState());

  Future<void> ladenWennNoetig() {
    if (state.geladen) return Future<void>.value();
    return _laeuft ??= laden().whenComplete(() => _laeuft = null);
  }

  Future<void> laden() => _fuehreAus(_neuLaden);

  /// Legt an oder schreibt, je nachdem, ob der Anfang schon eine Nummer hat.
  /// Liefert true, wenn es geklappt hat.
  Future<bool> speichere(Anredebaustein baustein) => _fuehreAus(() async {
    baustein.istGespeichert
        ? await _repository.aktualisiere(baustein)
        : await _repository.lege(baustein);
    await _neuLaden();
  });

  Future<bool> loesche(int id) => _fuehreAus(() async {
    await _repository.loesche(id);
    await _neuLaden();
  });

  /// Nach jedem Schreiben den ganzen Bestand neu holen: Die Reihenfolge liegt
  /// beim Dienst, eine von Hand einsortierte Zeile stünde falsch.
  Future<void> _neuLaden() async {
    final bausteine = await _repository.ladeAnredebausteine();
    if (isClosed) return;
    emit(state.kopie(bausteine: bausteine, geladen: true));
  }

  Future<bool> _fuehreAus(Future<void> Function() arbeit) async {
    emit(state.kopie(laedt: true));
    try {
      await arbeit();
      if (!isClosed) emit(state.kopie(laedt: false));
      return true;
    } catch (fehler) {
      if (!isClosed) {
        emit(state.kopie(laedt: false, fehler: _klartext(fehler)));
      }
      return false;
    }
  }

  /// `Exception: …` ist der Präfix aus `toString()`; im Dialog stünde er vor
  /// jedem Satz, den das Backend geschickt hat.
  static String _klartext(Object fehler) =>
      fehler.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
