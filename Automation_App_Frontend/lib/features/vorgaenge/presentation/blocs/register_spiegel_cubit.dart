import 'dart:async';

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

  /// Der Lauf, der gerade unterwegs ist — oder null.
  Future<void>? _laufend;

  RegisterSpiegelCubit(this._repository)
    : super(RegisterSpiegelErgebnis.unbekannt);

  /// Schützt vor einem zweiten Lauf, solange einer offen ist. Bewusst **kein**
  /// Anzeigezustand: Ein Cubit verwirft ein `emit` mit gleichem Wert, ein Knopf
  /// ließe sich darüber also nicht sperren. Das tut die Seite selbst.
  bool get laeuft => _laufend != null;

  /// Holt den letzten Stand, ohne zu schreiben — für das Öffnen der Seite.
  ///
  /// Läuft schon etwas, wird nicht gewartet: Die Anzeige aufzufrischen ist
  /// nicht dringend, und jeder Lauf hinterlässt ohnehin einen frischen Stand.
  Future<void> ladeStand() async {
    if (_laufend != null) return;
    await _fuehreAus(_repository.ladeStand);
  }

  /// Schreibt den Spiegel neu. Erzwingt: Hinter dem Knopf steht in aller Regel
  /// „die Datei ist weg oder sieht falsch aus", und ein „nichts zu tun" wäre
  /// darauf die unbrauchbarste aller Antworten.
  ///
  /// Ein Knopfdruck wird **eingereiht** statt verworfen. Beim Öffnen der Seite
  /// läuft `ladeStand()`, und das dauert eine Netzwerkrunde: Wer in dieser
  /// Sekunde drückt, sah vorher nur ein kurzes Blinken des Knopfes und danach
  /// denselben Stand wie zuvor — ohne jeden Hinweis, dass sein Druck ins Leere
  /// ging.
  Future<void> exportiere() async {
    await _laufend;
    if (_laufend != null) return;
    await _fuehreAus(() => _repository.exportiere(erzwingen: true));
  }

  /// Führt einen Lauf aus und hält fest, dass er unterwegs ist. Der
  /// [Completer] steht dafür ein, dass `_laufend` gesetzt ist, bevor die erste
  /// Unterbrechung kommt — sonst könnte ein Aufruf, der sofort zurückkehrt,
  /// die Markierung wieder löschen, ehe sie gesetzt wurde.
  Future<void> _fuehreAus(
    Future<RegisterSpiegelErgebnis> Function() arbeit,
  ) async {
    final abschluss = Completer<void>();
    _laufend = abschluss.future;
    try {
      emit(await arbeit());
    } on Exception catch (fehler) {
      emit(RegisterSpiegelErgebnis(fehler: _satz(fehler)));
    } finally {
      _laufend = null;
      abschluss.complete();
    }
  }

  /// Der Dienst antwortet auf beide Wege mit 200 und einem Stand; hier landet
  /// nur, was gar nicht erst ankam — Dienst nicht erreichbar, Zeitüberschreitung.
  String _satz(Exception fehler) =>
      'Der Register-Export ist nicht erreichbar: $fehler';
}
