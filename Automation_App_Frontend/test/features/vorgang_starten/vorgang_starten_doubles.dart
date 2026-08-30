import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';

/// Ein Mandantenregister im Speicher, das sich **einen** Bestand mit allen drei
/// UseCases teilt, die am Vorgang-starten-Formular hängen: Liste laden (View),
/// anlegen und aktualisieren (Bloc).
///
/// Der geteilte Bestand ist der Punkt. Mit drei unabhängigen Doubles bliebe
/// genau der Fehler unsichtbar, um den es hier geht: dass ein zweiter Klick auf
/// „Speichern" denselben Mandanten noch einmal anzulegen versucht. [anlagen]
/// zählt die Versuche mit — auch die gescheiterten.
///
/// Das Register bildet die beiden fachlichen Antworten des Backends nach, denn
/// ohne sie prüfen die Tests eine Welt, die es nicht gibt: den **Namenskonflikt**
/// (`MandantenRepository.EnsureNameUniqueAsync` → 409) und den **unbekannten
/// Mandanten** beim Aktualisieren (404). Ein Double, das beides klaglos
/// hinnimmt, macht aus der Sackgasse eine harmlose Dublette und lässt den Test
/// den falschen Schaden beschreiben.
class MandantenRegisterDouble {
  final List<Mandant> bestand = [];
  int anlagen = 0;
  int aktualisierungen = 0;
  int naechsteId = 7;

  /// Setzt einen Mandanten in den Bestand, als wäre er längst angelegt — ohne
  /// [anlagen] hochzuzählen. Wer zum Einrichten [anlegen] nimmt, startet mit
  /// einem Zähler auf 1 und kann die zweite Anlage nicht mehr von der ersten
  /// unterscheiden.
  Mandant hinterlege(CreateMandantRequest anfrage) {
    final mandant = _baue(anfrage);
    bestand.add(mandant);
    return mandant;
  }

  /// Legt an — oder meldet den Namenskonflikt, den auch das Backend meldet.
  /// Verglichen wird wie dort: Vor- und Nachname getrimmt und kleingeschrieben.
  Either<Failure, Mandant> anlegen(CreateMandantRequest anfrage) {
    anlagen++;
    final gesucht = _namensschluessel(anfrage.vorname, anfrage.nachname);
    final schonDa = bestand.any(
      (m) => _namensschluessel(m.vorname, m.nachname) == gesucht,
    );
    if (schonDa) {
      final anzeige = '${anfrage.vorname} ${anfrage.nachname}'.trim();
      return Left(
        ServerFailure(
          message:
              'Ein Mandant mit dem Namen „$anzeige" ist bereits vorhanden.',
        ),
      );
    }
    final mandant = _baue(anfrage);
    bestand.add(mandant);
    return Right(mandant);
  }

  /// Schreibt den geänderten Mandanten zurück — oder meldet ihn als unbekannt,
  /// wie das Backend mit 404. Stillschweigend anzulegen, was nicht da ist,
  /// verdeckte gerade den Fall, in dem die View eine tote Id mit sich trägt.
  Either<Failure, Mandant> aktualisieren(Mandant mandant) {
    aktualisierungen++;
    final index = bestand.indexWhere((m) => m.id == mandant.id);
    if (index < 0) {
      return Left(
        ServerFailure(message: 'Mandant ${mandant.id} wurde nicht gefunden.'),
      );
    }
    bestand[index] = mandant;
    return Right(mandant);
  }

  String _namensschluessel(String vorname, String nachname) =>
      '${vorname.trim().toLowerCase()} ${nachname.trim().toLowerCase()}'.trim();

  Mandant _baue(CreateMandantRequest anfrage) => Mandant(
    id: naechsteId++,
    anrede: anfrage.anrede,
    vorname: anfrage.vorname,
    nachname: anfrage.nachname,
    strasseHausnummer: anfrage.strasseHausnummer,
    postleitzahl: anfrage.postleitzahl,
    ort: anfrage.ort,
    emailAdresse: anfrage.emailAdresse,
    telefonnummer: anfrage.telefonnummer,
    notiz: anfrage.notiz,
    aktenOrdnernamen: anfrage.aktenOrdnernamen,
    kennzeichen: anfrage.kennzeichen,
    erstelltAm: DateTime(2026),
  );
}

/// Legt im [register] an und merkt sich die letzte Anfrage.
class MandantAnlegenDouble implements UseCase<Mandant, CreateMandantRequest> {
  final MandantenRegisterDouble register;
  CreateMandantRequest? letzteAnfrage;

  MandantAnlegenDouble(this.register);

  @override
  Future<Either<Failure, Mandant>> call(CreateMandantRequest params) async {
    letzteAnfrage = params;
    return register.anlegen(params);
  }
}

/// Schreibt den geänderten Mandanten in den [register]-Bestand zurück.
class MandantAktualisierenDouble implements UseCase<Mandant, Mandant> {
  final MandantenRegisterDouble register;

  MandantAktualisierenDouble(this.register);

  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async =>
      register.aktualisieren(params);
}

/// Der Abruf, den die View für Dropdown und Kennzeichen-Chips benutzt. Liefert
/// eine Kopie, damit ein Test die Liste nicht an der Fassade vorbei ändert.
class MandantenListeDouble implements UseCase<List<Mandant>, NoParams> {
  final MandantenRegisterDouble register;

  MandantenListeDouble(this.register);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async =>
      Right(List.of(register.bestand));
}

/// Liefert eine feste Referenz zurück, statt einen Browser zu öffnen.
class FesterZentralrufPrefill
    implements UseCase<ZentralrufPrefillResult, ZentralrufRequest> {
  final ZentralrufPrefillResult ergebnis;
  ZentralrufRequest? letzteAnfrage;

  FesterZentralrufPrefill(this.ergebnis);

  @override
  Future<Either<Failure, ZentralrufPrefillResult>> call(
    ZentralrufRequest params,
  ) async {
    letzteAnfrage = params;
    return Right(ergebnis);
  }
}

/// Das Vorbefüllen scheitert (Browser geschlossen, Zeitüberschreitung). Der
/// Schritt davor — die Mandantenanlage — ist da schon durch: genau die Lage,
/// in der ein Mandant im Register liegt, von dem die Oberfläche nichts weiß.
class ScheiterndeZentralrufVorbefuellung
    implements UseCase<ZentralrufPrefillResult, ZentralrufRequest> {
  @override
  Future<Either<Failure, ZentralrufPrefillResult>> call(
    ZentralrufRequest params,
  ) async => Left(
    ServerFailure(message: 'Das Zentralruf-Formular ließ sich nicht öffnen.'),
  );
}

/// Hält das Vorbefüllen an, bis der Test [gib] ruft.
///
/// Damit lässt sich das Fenster nachstellen, das im Betrieb bis zu drei Minuten
/// offen steht: Der Browser wartet auf das Captcha, das Formular bleibt
/// bedienbar, und der Anwalt tippt weiter. Was er in dieser Zeit ändert, darf
/// die Nachbereitung nicht überschreiben.
class AngehalteneZentralrufVorbefuellung
    implements UseCase<ZentralrufPrefillResult, ZentralrufRequest> {
  final ZentralrufPrefillResult ergebnis;
  final Completer<void> _tor = Completer<void>();

  AngehalteneZentralrufVorbefuellung(this.ergebnis);

  /// Ob der Bloc inzwischen im Vorbefüllen steht und wartet.
  bool get laeuft => _angefragt && !_tor.isCompleted;
  bool _angefragt = false;

  void gib() => _tor.complete();

  @override
  Future<Either<Failure, ZentralrufPrefillResult>> call(
    ZentralrufRequest params,
  ) async {
    _angefragt = true;
    await _tor.future;
    return Right(ergebnis);
  }
}

/// Kanzleidaten sind nicht hinterlegt — der Bloc muss auch dann durchlaufen
/// (der Anfrager-Block bleibt dann leer).
class OhneKanzleiEinstellungen implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Left(LocalFailure(message: 'keine Einstellungen'));
}

/// Vorgangsablage im Speicher: hält den Upsert über die Referenz nach, damit
/// sichtbar bleibt, ob ein Vorgang entstanden ist. [entwuerfe] zählt mit, was
/// als angefangener Ausfüllstand abgelegt (bzw. mit `null` verworfen) wurde.
class VorgangAblageDouble implements VorgangRepository {
  List<Vorgang> vorgaenge = const [];
  final List<VorgangEntwurf?> entwuerfe = [];

  @override
  Future<Vorgang?> setzeEntwurf(
    String referenz,
    VorgangEntwurf? entwurf,
  ) async {
    entwuerfe.add(entwurf);
    for (final vorhanden in vorgaenge) {
      if (!Vorgang.gleicheReferenz(vorhanden.referenz, referenz)) continue;
      return upsertVorgang(vorhanden.copyWith(entwurf: () => entwurf));
    }
    return null;
  }

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;

  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async {
    vorgaenge = [
      ...vorgaenge.where(
        (v) => !Vorgang.gleicheReferenz(v.referenz, vorgang.referenz),
      ),
      vorgang,
    ];
    return vorgang;
  }

  @override
  Future<void> deleteVorgang(String referenz) async {
    vorgaenge = vorgaenge
        .where((v) => !Vorgang.gleicheReferenz(v.referenz, referenz))
        .toList();
  }

  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async => null;

  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async => null;
}
