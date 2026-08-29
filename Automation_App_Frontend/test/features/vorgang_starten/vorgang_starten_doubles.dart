import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';

/// Ein Mandantenregister im Speicher, das sich **einen** Bestand mit allen drei
/// UseCases teilt, die am Vorgang-starten-Formular hängen: Liste laden (View),
/// anlegen und aktualisieren (Bloc).
///
/// Der geteilte Bestand ist der Punkt. Mit drei unabhängigen Doubles bliebe
/// genau der Fehler unsichtbar, um den es hier geht: dass ein zweiter Klick auf
/// „Speichern" denselben Mandanten ein zweites Mal anlegt. [anlagen] zählt mit.
class MandantenRegisterDouble {
  final List<Mandant> bestand = [];
  int anlagen = 0;
  int aktualisierungen = 0;
  int naechsteId = 7;

  Mandant anlegen(CreateMandantRequest anfrage) {
    anlagen++;
    final mandant = Mandant(
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
    bestand.add(mandant);
    return mandant;
  }

  Mandant aktualisieren(Mandant mandant) {
    aktualisierungen++;
    final index = bestand.indexWhere((m) => m.id == mandant.id);
    if (index < 0) {
      bestand.add(mandant);
    } else {
      bestand[index] = mandant;
    }
    return mandant;
  }
}

/// Legt im [register] an und merkt sich die letzte Anfrage.
class MandantAnlegenDouble implements UseCase<Mandant, CreateMandantRequest> {
  final MandantenRegisterDouble register;
  CreateMandantRequest? letzteAnfrage;

  MandantAnlegenDouble(this.register);

  @override
  Future<Either<Failure, Mandant>> call(CreateMandantRequest params) async {
    letzteAnfrage = params;
    return Right(register.anlegen(params));
  }
}

/// Schreibt den geänderten Mandanten in den [register]-Bestand zurück.
class MandantAktualisierenDouble implements UseCase<Mandant, Mandant> {
  final MandantenRegisterDouble register;

  MandantAktualisierenDouble(this.register);

  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async =>
      Right(register.aktualisieren(params));
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

/// Kanzleidaten sind nicht hinterlegt — der Bloc muss auch dann durchlaufen
/// (der Anfrager-Block bleibt dann leer).
class OhneKanzleiEinstellungen implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Left(LocalFailure(message: 'keine Einstellungen'));
}

/// Vorgangsablage im Speicher: hält den Upsert über die Referenz nach, damit
/// sichtbar bleibt, ob ein Vorgang entstanden ist.
class VorgangAblageDouble implements VorgangRepository {
  List<Vorgang> vorgaenge = const [];

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
