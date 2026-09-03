import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/repositories/grussformeln_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/bestand_arbeit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Bestand der persönlichen Grußformeln (§4.7, §7.1) — gepflegt in den
/// Einstellungen, gewählt im Versanddialog.
///
/// Ein Singleton aus demselben Grund wie `MailVorlagenCubit`: Beide Seiten
/// meinen denselben Bestand, und wer einen Gruß anlegt und danach schreibt,
/// soll ihn vorfinden.
@lazySingleton
class GrussformelnCubit extends Cubit<GrussformelnState>
    with BestandArbeit<GrussformelnState> {
  final GrussformelnRepository _repository;

  /// Der laufende Abruf — Verwaltung und Versanddialog fragen beide beim
  /// Aufgehen.
  Future<void>? _laeuft;

  GrussformelnCubit(this._repository) : super(const GrussformelnState());

  Future<void> ladenWennNoetig() {
    if (state.geladen) return Future<void>.value();
    return _laeuft ??= laden().whenComplete(() => _laeuft = null);
  }

  Future<void> laden() => fuehreAus(_neuLaden);

  /// Legt an oder schreibt, je nachdem, ob der Gruß schon eine Nummer hat.
  /// Liefert true, wenn es geklappt hat.
  Future<bool> speichere(Grussformel grussformel) => fuehreAus(() async {
    grussformel.istGespeichert
        ? await _repository.aktualisiere(grussformel)
        : await _repository.lege(grussformel);
    await _neuLaden();
  });

  Future<bool> loesche(int id) => fuehreAus(() async {
    await _repository.loesche(id);
    await _neuLaden();
  });

  /// Nach jedem Schreiben den ganzen Bestand neu holen: Die Reihenfolge liegt
  /// beim Dienst, eine von Hand einsortierte Zeile stünde falsch.
  Future<void> _neuLaden() async {
    final grussformeln = await _repository.ladeGrussformeln();
    if (isClosed) return;
    emit(state.kopie(grussformeln: grussformeln, geladen: true));
  }

  /// Die eine Zeile, die dieser Bestand zum gemeinsamen Rahmen beisteuert.
  @override
  GrussformelnState mitLadestand({required bool laedt, String? fehler}) =>
      state.kopie(laedt: laedt, fehler: fehler);
}
