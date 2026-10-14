import 'dart:async';
import 'dart:collection';

import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/letzte_aktualisierung.dart';
import 'package:automation_app/core/aktualisierung/domain/repositories/aktualisierung_repository.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';

/// Wie GitHub die Setup-Datei meldet — nur so eine Adresse öffnet
/// `BrowserOeffner`.
const String setupAdresse =
    'https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/'
    'Automation_App_Setup_1.4.0.exe';

/// Ein Stand, wie der Dienst ihn meldet — mit den Werten der Vorschau.
AktualisierungsStand standMit(
  AktualisierungsZustand zustand, {
  String? neueVersion = '1.4.0',
  int geladen = 0,
  int? gesamt = 92 * 1024 * 1024,
  String? meldung,
  AktualisierungsFehlerArt? fehlerArt,
  String? downloadUrl = setupAdresse,
  LetzteAktualisierung? letzte,
}) => AktualisierungsStand(
  laufendeVersion: '1.3.0',
  neueVersion: neueVersion,
  zustand: zustand,
  geladenBytes: geladen,
  gesamtBytes: gesamt,
  meldung: meldung,
  fehlerArt: fehlerArt,
  downloadUrl: downloadUrl,
  letzteAktualisierung: letzte,
);

/// Antwort eines Schritts: ein Stand oder eine Ablehnung mit Satz.
typedef Antwort = Either<Failure, AktualisierungsStand>;

Antwort ok(AktualisierungsStand stand) => Right(stand);

Antwort abgelehnt(String satz) => Left(ServerFailure(message: satz));

/// Ein Port, der antwortet, ohne einen Dienst zu brauchen, und mitschreibt,
/// was gefragt wurde. Je Schritt eine Warteschlange von Antworten; ist sie
/// leer, gilt die letzte noch einmal (bei `stand` der zuletzt gemeldete).
class AktualisierungRepositoryDouble implements AktualisierungRepository {
  AktualisierungRepositoryDouble({AktualisierungsStand? anfang})
    : _letzter = anfang ?? standMit(AktualisierungsZustand.verfuegbar);

  AktualisierungsStand _letzter;
  final List<String> aufrufe = [];

  final Queue<Antwort> staende = Queue();
  final Queue<Antwort> pruefungen = Queue();
  final Queue<Antwort> downloads = Queue();
  final Queue<Antwort> abbrueche = Queue();
  final Queue<Antwort> installationen = Queue();
  int quittungen = 0;

  int zaehle(String schritt) => aufrufe.where((a) => a == schritt).length;

  Future<Antwort> _antworte(String schritt, Queue<Antwort> schlange) async {
    aufrufe.add(schritt);
    final antwort = schlange.isNotEmpty
        ? schlange.removeFirst()
        : Right<Failure, AktualisierungsStand>(_letzter);
    if (antwort case Right(:final value)) _letzter = value;
    return antwort;
  }

  @override
  Future<Antwort> stand() => _antworte('stand', staende);

  @override
  Future<Antwort> pruefen() => _antworte('pruefen', pruefungen);

  @override
  Future<Antwort> herunterladen() => _antworte('herunterladen', downloads);

  @override
  Future<Antwort> abbrechen() => _antworte('abbrechen', abbrueche);

  @override
  Future<Antwort> installieren() => _antworte('installieren', installationen);

  @override
  Future<Either<Failure, void>> ergebnisQuittieren() async {
    aufrufe.add('quittieren');
    quittungen++;
    return Right(null);
  }
}

/// Ersetzt das Warten des Cubits: Jeder Aufruf wartet, bis der Test ihn mit
/// [weiter] freigibt — so lässt sich das Abfragen Schritt für Schritt prüfen.
class TaktDouble {
  final List<Duration> gewartet = [];
  final Queue<Completer<void>> _offen = Queue();

  Future<void> warte(Duration dauer) {
    gewartet.add(dauer);
    final schritt = Completer<void>();
    _offen.add(schritt);
    return schritt.future;
  }

  /// Wie viele Wartende noch auf Freigabe stehen.
  int get offen => _offen.length;

  /// Gibt den ältesten Wartenden frei — in einem Widget-Test danach
  /// `tester.pump()`, dort läuft keine echte Zeit.
  void freigeben() => _offen.removeFirst().complete();

  /// Gibt den ältesten Wartenden frei und lässt die Folgen durchlaufen.
  Future<void> weiter() async {
    freigeben();
    await pumpeMikroaufgaben();
  }
}

/// Lässt alle anstehenden Futures durchlaufen, ohne echte Zeit zu warten.
Future<void> pumpeMikroaufgaben() async {
  for (var runde = 0; runde < 20; runde++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Ein Cubit über [repository]; Beenden zählt nur mit.
class CubitAufbau {
  CubitAufbau({
    AktualisierungRepositoryDouble? repository,
    bool testmodus = false,
  }) : repository = repository ?? AktualisierungRepositoryDouble() {
    cubit = AktualisierungCubit(
      this.repository,
      testmodus: testmodus,
      beenden: () async {
        beendet++;
      },
      warten: takt.warte,
    );
  }

  final AktualisierungRepositoryDouble repository;
  final TaktDouble takt = TaktDouble();
  late final AktualisierungCubit cubit;
  int beendet = 0;
}
