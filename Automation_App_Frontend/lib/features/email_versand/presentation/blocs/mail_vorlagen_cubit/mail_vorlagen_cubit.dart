import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/repositories/mail_vorlagen_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/bestand_arbeit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Bestand der Mail-Textvorlagen (§4.7, §5.3) — gepflegt in den
/// Einstellungen, gelesen beim Verfassen.
///
/// Ein Singleton, weil beide Seiten denselben Bestand meinen: Wer eine Vorlage
/// in den Einstellungen ändert und danach eine Mail schreibt, soll die
/// geänderte Fassung vorfinden und nicht die des letzten Abrufs.
@lazySingleton
class MailVorlagenCubit extends Cubit<MailVorlagenState>
    with BestandArbeit<MailVorlagenState> {
  final MailVorlagenRepository _repository;

  /// Der laufende Abruf. Verwaltung und Versanddialog fragen beide beim
  /// Aufgehen; ohne diesen Griff stellte der zweite dieselbe Anfrage, weil die
  /// erste noch unterwegs ist.
  Future<void>? _laeuft;

  MailVorlagenCubit(this._repository) : super(const MailVorlagenState());

  /// Holt den Bestand, wenn er noch nicht da ist.
  Future<void> ladenWennNoetig() {
    if (state.geladen) return Future<void>.value();
    return _laeuft ??= laden().whenComplete(() => _laeuft = null);
  }

  Future<void> laden() => fuehreAus(_neuLaden);

  /// Legt an oder schreibt, je nachdem, ob die Vorlage schon eine Nummer hat.
  /// Liefert true, wenn es geklappt hat — der Dialog schliesst sich nur dann.
  Future<bool> speichere(MailVorlage vorlage) => fuehreAus(() async {
    vorlage.istGespeichert
        ? await _repository.aktualisiere(vorlage)
        : await _repository.lege(vorlage);
    await _neuLaden();
  });

  Future<bool> loesche(int id) => fuehreAus(() async {
    await _repository.loesche(id);
    await _neuLaden();
  });

  /// Nach jedem Schreiben den ganzen Bestand neu holen, statt die Liste
  /// nachzupflegen: Die Sortierung liegt beim Dienst (nach Namen), und eine
  /// von Hand einsortierte Zeile stünde nach einer Umbenennung falsch.
  Future<void> _neuLaden() async {
    final vorlagen = await _repository.ladeVorlagen();
    if (isClosed) return;
    emit(state.kopie(vorlagen: vorlagen, geladen: true));
  }

  /// Die eine Zeile, die dieser Bestand zum gemeinsamen Rahmen beisteuert.
  @override
  MailVorlagenState mitLadestand({required bool laedt, String? fehler}) =>
      state.kopie(laedt: laedt, fehler: fehler);
}
