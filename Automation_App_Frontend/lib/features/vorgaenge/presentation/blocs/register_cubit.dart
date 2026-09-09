import 'dart:async';

import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_historie_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_zeilen_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Zustand der Registeransicht (§6.2): Zeilen, Stand der übernommenen
/// Historie und die Auswahl darüber.
///
/// Bewusst **nicht** der app-weite `VorgangCubit`: Die Zeilen kommen seit
/// Issue #109 fertig gebaut aus dem Backend und enthalten auch die
/// Registerhistorie, die als Vorgang gar nicht existiert. Der Cubit hängt
/// deshalb an der Seite (`factory`, vom `BlocProvider` geschlossen) und nicht
/// an der App.
@injectable
class RegisterCubit extends Cubit<RegisterState> {
  final RegisterZeilenRepository _zeilen;
  final RegisterHistorieRepository _historie;

  RegisterCubit(this._zeilen, this._historie) : super(const RegisterState());

  /// Holt Zeilen und Stand. Beides in einem Aufruf, weil beides zusammen
  /// gezeigt wird: Ein Stand, der einen Jahrgang als übernommen meldet, dessen
  /// Zeilen aber noch fehlen, wäre schlimmer als gar keiner.
  ///
  /// Beide Aufrufe laufen parallel statt nacheinander — sie sind voneinander
  /// unabhängig, und nacheinander gewartet verdoppelte nur die Wartezeit.
  /// Schlägt einer fehl, verpackt `.wait` ihn in einen [ParallelWaitError];
  /// der eigene Fang wickelt ihn wieder aus, damit die Meldung unverändert
  /// bleibt.
  Future<void> lade() async {
    emit(state.copyWith(laedt: true, fehlerLoeschen: true));
    try {
      final (zeilen, stand) = await (
        _zeilen.ladeZeilen(),
        _historie.ladeStand(),
      ).wait;
      emit(state.copyWith(zeilen: zeilen, stand: stand, laedt: false));
    } on ParallelWaitError catch (fehler) {
      _nichtErreichbar(fehler.errors.$1?.error ?? fehler.errors.$2?.error);
    } on Exception catch (fehler) {
      _nichtErreichbar(fehler);
    }
  }

  void _nichtErreichbar(Object? fehler) => emit(
    state.copyWith(
      laedt: false,
      fehler: 'Das Register ist nicht erreichbar: $fehler',
    ),
  );

  /// Setzt die Auswahl. Sie liegt im Cubit und nicht in der Seite, damit ein
  /// Nachladen sie nicht zurückwirft.
  void filtern(RegisterFilter filter) => emit(state.copyWith(filter: filter));

  /// Dreht die Leserichtung — aus demselben Grund hier und nicht in der Seite.
  void sortieren(RegisterReihenfolge reihenfolge) =>
      emit(state.copyWith(reihenfolge: reihenfolge));

  /// Holt den Rohstand einer historischen Zeile — die Einzelfelder, mit denen
  /// der Bearbeiten-Dialog aufgeht. `null`, wenn der Dienst sie nicht liefert;
  /// die Oberfläche sagt das dann, statt einen leeren Dialog zu öffnen.
  ///
  /// Erst beim Öffnen und nicht mit der Tabelle: Der Zeilen-Endpunkt trägt die
  /// Anzeigeform, und für tausende Zeilen die Einzelfelder mitzuschleppen wäre
  /// Ballast für den einen Klick, der sie braucht.
  Future<RegisterHistorieZeile?> ladeHistorieZeile(int id) async {
    try {
      return await _historie.lade(id);
    } on Exception {
      return null;
    }
  }

  /// Berichtigt eine historische Zeile und lädt danach neu. Liefert `false`,
  /// wenn der Dienst die Änderung nicht angenommen hat — die Oberfläche sagt
  /// das dann über `Rueckmeldung`, statt still zu tun, als wäre es geschehen.
  ///
  /// Neu geladen wird **alles**: Eine Berichtigung rechnet die Befunde der
  /// Zeile neu und verschiebt damit auch die Zahlen im Stand ihres Jahrgangs.
  Future<bool> aendereHistorie(
    int id,
    RegisterHistorieAenderung aenderung,
  ) async {
    try {
      await _historie.aendere(id, aenderung);
    } on Exception {
      return false;
    }
    await lade();
    return true;
  }

  /// Löscht eine historische Zeile für sich (§6.3) und lädt danach neu — wie
  /// bei einer Berichtigung verschiebt das auch die Zahlen im Stand ihres
  /// Jahrgangs. Liefert `false`, wenn der Dienst es nicht angenommen hat.
  Future<bool> loescheHistorie(int id) async {
    try {
      await _historie.loesche(id);
    } on Exception {
      return false;
    }
    await lade();
    return true;
  }
}
