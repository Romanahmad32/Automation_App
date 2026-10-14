import 'dart:async';

import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/domain/repositories/aktualisierung_repository.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/backend/anwendung_beenden.dart';
import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Wartet die angegebene Dauer — im Test durch einen Takt ersetzbar.
typedef AktualisierungsWarten = Future<void> Function(Duration dauer);

/// Trägt die Aktualisierung aus der App heraus (#196): beim Start prüfen,
/// herunterladen und dabei den Fortschritt abfragen, abbrechen, installieren
/// und danach die App beenden, das Ergebnis der letzten Aktualisierung
/// quittieren.
///
/// `@lazySingleton`: Seitenleiste, Dialog und „Über“ zeigen denselben Stand,
/// und der Download läuft weiter, wenn der Dialog zu ist.
///
/// **Abgefragt wird nur während `laedt`** — alle [abfrageTakt] ein
/// `GET api/Aktualisierung`. Sonst ändert sich der Stand nur durch die eigenen
/// Schritte, und jede Antwort trägt ihn ganz.
@lazySingleton
class AktualisierungCubit extends Cubit<AktualisierungsAnsicht> {
  AktualisierungCubit(
    this._repository, {
    @ignoreParam this.testmodus = BackendEndpoint.testmodusErwartet,
    @ignoreParam this._beenden = AnwendungBeenden.regulaer,
    @ignoreParam this._warten = _echtWarten,
  }) : super(AktualisierungsAnsicht.anfang);

  final AktualisierungRepository _repository;

  /// Im E2E-Testmodus startet der Dienst keinen Installer (nur eine
  /// Protokollzeile), und die App bleibt offen — sonst endete mitten im
  /// Durchlauf die Suite. Ein Parameter statt der Konstante, damit sich der
  /// Zweig testen lässt.
  final bool testmodus;

  final Future<void> Function() _beenden;
  final AktualisierungsWarten _warten;

  static const Duration abfrageTakt = Duration(milliseconds: 500);

  /// So lange steht „Die App wird jetzt geschlossen …“ (2e), bevor sie zugeht
  /// — lang genug, um es zu lesen; der Installer wartet ohnehin auf den Dienst.
  static const Duration schliessPause = Duration(seconds: 2);

  /// So viele Abfragen in Folge dürfen während des Downloads scheitern, bevor
  /// eine Meldung erscheint — ein einzelner Aussetzer ist kein Fehler.
  static const int stummeAbfragenBisMeldung = 3;

  /// Nach der Meldung wird langsamer weiter abgefragt, bis der Dienst wieder
  /// antwortet — ohne ihn im halbsekündlichen Takt anzurennen.
  static const Duration ruhigerTakt = Duration(seconds: 2);

  static const String testmodusHinweis =
      'Testmodus: Das Installationsprogramm wurde nur protokolliert, nicht '
      'gestartet — die App bleibt offen.';

  bool _gestartet = false;
  bool _beobachtet = false;
  bool _ergebnisGesehen = false;

  static Future<void> _echtWarten(Duration dauer) =>
      Future<void>.delayed(dauer);

  /// Einmal je Sitzung, beim Aufbau der Oberfläche: erst den Stand holen —
  /// schnell, und mit dem Ergebnis der letzten Aktualisierung —, dann die
  /// Update-Quelle fragen lassen (das kann bis zu zehn Sekunden dauern).
  Future<void> beimStart() async {
    if (_gestartet) return;
    _gestartet = true;
    await auffrischen();
    await pruefen();
  }

  /// Holt den Stand, still: Ein Fehler zeigt nur „konnte nicht nachsehen“.
  Future<void> auffrischen() async =>
      _stillUebernehmen(await _repository.stand());

  /// Lässt den Dienst nachsehen, still — ohne Netz passiert schlicht nichts.
  Future<void> pruefen() async =>
      _stillUebernehmen(await _repository.pruefen());

  /// „Jetzt aktualisieren“ (2a).
  Future<void> herunterladen() async {
    if (state.arbeitet) return;
    await _schritt(_repository.herunterladen);
  }

  /// „Laden abbrechen“ (2b) — zurück zu 2a.
  Future<void> abbrechen() async {
    if (state.arbeitet) return;
    await _schritt(_repository.abbrechen);
  }

  /// „Erneut versuchen“ (2d, und die Rückmeldung nach einem gescheiterten
  /// Update): erst neu nachsehen — fehlte die Setup-Datei, kann sie jetzt da
  /// sein —, dann laden, wenn es etwas zu laden gibt.
  Future<void> erneutVersuchen() async {
    if (state.arbeitet) return;
    emit(state.mit(arbeitet: true));
    final geprueft = await _repository.pruefen();
    if (isClosed) return;
    switch (geprueft) {
      case Left(:final value):
        emit(state.mit(arbeitet: false, ablehnung: value.message));
        return;
      case Right(:final value):
        final laden = value.zustand == AktualisierungsZustand.verfuegbar;
        _uebernimm(value, arbeitet: laden);
        if (!laden) return;
    }
    await _schritt(_repository.herunterladen);
  }

  /// „Jetzt neu starten“ (2c): Installer starten lassen, 2e zeigen, die App
  /// beenden — im Testmodus stattdessen nur den Dialog schließen.
  Future<void> installieren() async {
    if (state.arbeitet || state.schliesstGerade) return;
    emit(state.mit(arbeitet: true));
    final ergebnis = await _repository.installieren();
    if (isClosed) return;
    switch (ergebnis) {
      case Left(:final value):
        await _abgelehnt(value.message);
      case Right(:final value) when testmodus:
        _uebernimm(value, arbeitet: false, testmodusNeustart: true);
      case Right(:final value):
        _uebernimm(value, arbeitet: false, schliesstGerade: true);
        await _warten(schliessPause);
        await _beenden();
    }
  }

  /// Das Ergebnis der letzten Aktualisierung ist gezeigt (3b/3c). Ab jetzt
  /// fällt es aus jedem Stand heraus — auch aus einer Antwort, die schon
  /// unterwegs war, als quittiert wurde.
  Future<void> ergebnisQuittieren() async {
    if (_ergebnisGesehen) return;
    _ergebnisGesehen = true;
    final stand = state.stand;
    if (stand?.letzteAktualisierung != null) {
      emit(state.mit(stand: stand!.ohneErgebnis()));
    }
    await _repository.ergebnisQuittieren();
  }

  Future<void> _schritt(
    Future<Either<Failure, AktualisierungsStand>> Function() aufruf,
  ) async {
    emit(state.mit(arbeitet: true));
    final ergebnis = await aufruf();
    if (isClosed) return;
    switch (ergebnis) {
      case Right(:final value):
        _uebernimm(value, arbeitet: false);
      case Left(:final value):
        await _abgelehnt(value.message);
    }
  }

  /// Nach einer Ablehnung den Stand neu holen: Bei einem 409 hat der Dienst
  /// ihn womöglich selbst geändert (etwa auf `fehler`). Steht der Satz dann
  /// schon im Dialog (2d), braucht es keine zweite Meldung daneben.
  Future<void> _abgelehnt(String satz) async {
    final nachher = await _repository.stand();
    if (isClosed) return;
    switch (nachher) {
      case Right(:final value):
        final imDialog =
            value.zustand == AktualisierungsZustand.fehler &&
            value.meldung == satz;
        _uebernimm(value, arbeitet: false, ablehnung: imDialog ? null : satz);
      case Left():
        emit(state.mit(arbeitet: false, ablehnung: satz));
    }
  }

  void _stillUebernehmen(Either<Failure, AktualisierungsStand> ergebnis) {
    if (isClosed) return;
    switch (ergebnis) {
      case Right(:final value):
        _uebernimm(value);
      case Left():
        emit(state.mit(dienstStumm: true));
    }
  }

  void _uebernimm(
    AktualisierungsStand stand, {
    bool? arbeitet,
    bool? schliesstGerade,
    String? ablehnung,
    bool testmodusNeustart = false,
  }) {
    final bereinigt = _ergebnisGesehen ? stand.ohneErgebnis() : stand;
    emit(
      state.mit(
        stand: bereinigt,
        dienstStumm: false,
        arbeitet: arbeitet,
        schliesstGerade: schliesstGerade,
        ablehnung: ablehnung,
        testmodusNeustart: testmodusNeustart,
      ),
    );
    if (bereinigt.zustand == AktualisierungsZustand.laedt) {
      unawaited(_beobachte());
    }
  }

  /// Fragt den Stand ab, solange geladen wird. Läuft höchstens einmal.
  ///
  /// Schweigt der Dienst, kommt nach [stummeAbfragenBisMeldung] Aussetzern
  /// einmal eine Meldung — aufgegeben wird nicht: Danach fragt er im
  /// [ruhigerTakt] weiter, und sobald der Dienst wieder antwortet, stimmt der
  /// Stand wieder. Sonst stünden Ring und Balken auf `laedt` still, auch wenn
  /// der Download längst fertig ist.
  Future<void> _beobachte() async {
    if (_beobachtet) return;
    _beobachtet = true;
    var stumm = 0;
    try {
      while (!isClosed && state.zustand == AktualisierungsZustand.laedt) {
        await _warten(
          stumm < stummeAbfragenBisMeldung ? abfrageTakt : ruhigerTakt,
        );
        if (isClosed) return;
        final ergebnis = await _repository.stand();
        if (isClosed) return;
        switch (ergebnis) {
          case Right(:final value):
            stumm = 0;
            _uebernimm(value);
          case Left(:final value):
            if (++stumm == stummeAbfragenBisMeldung) {
              emit(state.mit(ablehnung: value.message));
            }
        }
      }
    } finally {
      _beobachtet = false;
    }
  }
}
