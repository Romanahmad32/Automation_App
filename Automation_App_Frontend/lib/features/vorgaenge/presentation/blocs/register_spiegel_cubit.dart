import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Zustand des Register-Spiegels auf der Registerseite (§6.2).
///
/// Bewusst schmal: Der Spiegel wird ohnehin nach jedem Vorgangsabschluss im
/// Backend geschrieben. Diese Klasse trägt nur den Knopf „Jetzt neu schreiben"
/// und die Anzeige darunter — und `laeuft`, damit man nicht zweimal drückt,
/// während Word noch wandelt.
@injectable
class RegisterSpiegelCubit extends Cubit<RegisterSpiegelErgebnis> {
  final RegisterSpiegelRepository _repository;

  bool _laeuft = false;

  RegisterSpiegelCubit(this._repository)
    : super(RegisterSpiegelErgebnis.unbekannt);

  /// Schützt vor einem zweiten Lauf, solange einer offen ist. Bewusst **kein**
  /// Anzeigezustand: Ein Cubit verwirft ein `emit` mit gleichem Wert, ein Knopf
  /// ließe sich darüber also nicht sperren. Das tut die Seite selbst.
  bool get laeuft => _laeuft;

  /// Holt den letzten Stand, ohne zu schreiben — für das Öffnen der Seite.
  Future<void> ladeStand() async {
    if (_laeuft) return;
    _laeuft = true;
    try {
      emit(await _repository.ladeStand());
    } on Exception catch (fehler) {
      emit(RegisterSpiegelErgebnis(fehler: _satz(fehler)));
    } finally {
      _laeuft = false;
    }
  }

  /// Schreibt den Spiegel neu. Erzwingt: Hinter dem Knopf steht in aller Regel
  /// „die Datei ist weg oder sieht falsch aus", und ein „nichts zu tun" wäre
  /// darauf die unbrauchbarste aller Antworten.
  Future<void> exportiere() async {
    if (_laeuft) return;
    _laeuft = true;
    try {
      emit(await _repository.exportiere(erzwingen: true));
    } on Exception catch (fehler) {
      emit(RegisterSpiegelErgebnis(fehler: _satz(fehler)));
    } finally {
      _laeuft = false;
    }
  }

  /// Der Dienst antwortet auf beide Wege mit 200 und einem Stand; hier landet
  /// nur, was gar nicht erst ankam — Dienst nicht erreichbar, Zeitüberschreitung.
  String _satz(Exception fehler) =>
      'Der Register-Export ist nicht erreichbar: $fehler';
}
