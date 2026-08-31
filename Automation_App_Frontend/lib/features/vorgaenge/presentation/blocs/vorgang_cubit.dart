import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/services/antwort_konflikte.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/referenz_vergeben_exception.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/services/fallback_referenz.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_meldung.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// App-weiter, persistenter Speicher aller Vorgänge — die gemeinsame Klammer,
/// auf die die übrigen Features (Zentralruf-Anfrage, Antwort/Postfach,
/// Word-Ausfüllung, Ablage, Versand) zugreifen, statt dieselben Daten mehrfach
/// zu erfassen. Wird lokal persistiert und beim Start wiederhergestellt; die
/// Antwort des Zentralrufs kommt oft erst Tage nach der Anfrage, ein Neustart
/// darf den Vorgang nicht verlieren.
///
/// Fehlgeschlagene Persistenz wird nicht still geschluckt (§7.2), sondern an
/// den [VorgangPersistenzFehlerCubit] gemeldet; die Shell bietet dem Nutzer
/// „Erneut versuchen" an (→ [wiederhole]).
@lazySingleton
class VorgangCubit extends Cubit<List<Vorgang>> {
  final VorgangRepository _datasource;
  final VorgangPersistenzFehlerCubit _fehler;

  VorgangCubit(this._datasource, this._fehler) : super(const []) {
    ladeErneut();
  }

  /// Lädt die persistierten Vorgänge (beim Start und als Wiederholung nach
  /// einem Ladefehler). Überschreibt keine inzwischen erfassten Einträge.
  Future<void> ladeErneut() async {
    try {
      final gespeichert = await _datasource.loadVorgaenge();
      // Nur setzen, wenn nicht inzwischen schon etwas eingetragen wurde.
      if (state.isEmpty && gespeichert.isNotEmpty) emit(gespeichert);
    } catch (_) {
      _fehler.melde(VorgangPersistenzMeldung.laden());
    }
  }

  /// Beim Vorausfüllen des Anfrageformulars aufgerufen: legt den Vorgang an
  /// oder aktualisiert (gleiche Referenz erneut angefragt) den Zeitstempel,
  /// ohne bereits erfasste Felder zu verlieren.
  Future<void> registriereAnfrage(
    String referenz, {
    String rechtsgebiet = RechtsgebietWert.verkehrsrecht,
    int? mandantId,
    String? mandantName,
    String? unfallDatum,
    String? geschaedigtenKennzeichen,
    String? unfallort,
    String? unfalluhrzeit,
    String? polizeiVorgangsnummer,
  }) async {
    final bereinigt = referenz.trim();
    if (bereinigt.isEmpty) return;

    final bestehend = findeZuReferenz(bereinigt);
    // Ein erneutes Speichern darf bereits erfasste Antwort-/Dokumentdaten nicht
    // verlieren: bestehende Vorgänge werden über copyWith aktualisiert (das die
    // unberührten Felder durchreicht), neue über ausAnfrage angelegt.
    final vorgang = bestehend == null
        ? Vorgang.ausAnfrage(
            referenz: bereinigt,
            angefragtAm: DateTime.now(),
            rechtsgebiet: rechtsgebiet,
            mandantId: mandantId,
            mandantName: mandantName,
            unfallDatum: unfallDatum,
            geschaedigtenKennzeichen: geschaedigtenKennzeichen,
            unfallort: unfallort,
            unfalluhrzeit: unfalluhrzeit,
            polizeiVorgangsnummer: polizeiVorgangsnummer,
          )
        : bestehend.copyWith(
            rechtsgebiet: rechtsgebiet,
            mandantId: mandantId,
            mandantName: mandantName,
            unfallDatum: unfallDatum,
            geschaedigtenKennzeichen: geschaedigtenKennzeichen,
            unfallort: unfallort,
            unfalluhrzeit: unfalluhrzeit,
            polizeiVorgangsnummer: polizeiVorgangsnummer,
          );
    await _upsert(vorgang);
  }

  /// Ordnet eine eingegangene Zentralruf-Antwort einem Vorgang zu (§4.3) und
  /// schaltet ihn auf „beantwortet".
  ///
  /// [zielReferenz] ist der vom Anwalt im Antwort-/Postfach-Formular gewählte
  /// Zielvorgang und hat Vorrang vor der Referenz aus der Antwort — so lässt
  /// sich eine fehlgeschlagene oder falsche automatische Zuordnung von Hand
  /// korrigieren. Ist [zielReferenz] leer („Neuen Vorgang anlegen"), greift die
  /// Referenz der Antwort. Findet sich zu beidem kein Vorgang, wird ein eigener
  /// unter der gewünschten Referenz ergänzt; fehlt auch die, unter einer
  /// eindeutigen Ersatz-Referenz ([freieOhneReferenz]), damit sich mehrere
  /// referenzlose Antworten nicht gegenseitig überschreiben.
  ///
  /// [antwortGewinnt] sind die vom Anwalt im Konfliktdialog gewählten Felder,
  /// bei denen der Antwortwert einen bereits erfassten Wert ersetzen soll
  /// (siehe [AntwortKonflikte]); ohne Angabe bleiben erfasste Werte stehen.
  Future<void> uebernehmeAntwort(
    ZentralrufReplyData data, {
    String? zielReferenz,
    Set<AntwortKonfliktFeld> antwortGewinnt = const {},
  }) async {
    final bestehend = zielVorgangFuer(data, zielReferenz: zielReferenz);
    final vorgang = bestehend != null
        ? AntwortKonflikte.uebernehmen(
            bestehend,
            data,
            antwortGewinnt: antwortGewinnt,
          )
        : Vorgang.ausAnfrage(
            referenz:
                _gewuenschteReferenz(data, zielReferenz) ??
                freieOhneReferenz(state),
            angefragtAm: DateTime.now(),
          ).mitAntwort(data);
    await _upsert(vorgang);
  }

  /// Der bestehende Vorgang, den eine Übernahme dieser Antwort träfe — für
  /// die Konfliktprüfung ([AntwortKonflikte.finde]) vor dem eigentlichen
  /// [uebernehmeAntwort]. Null, wenn die Übernahme einen neuen Vorgang anlegt.
  Vorgang? zielVorgangFuer(ZentralrufReplyData data, {String? zielReferenz}) =>
      findeZuReferenz(_gewuenschteReferenz(data, zielReferenz));

  /// Referenz, unter der die Übernahme landet: die vom Anwalt gewählte
  /// Zielreferenz vor der Referenz aus der Antwort; null, wenn beide fehlen.
  String? _gewuenschteReferenz(ZentralrufReplyData data, String? zielReferenz) {
    final gewaehlt = zielReferenz?.trim();
    if (gewaehlt != null && gewaehlt.isNotEmpty) return gewaehlt;
    final ausAntwort = data.referenz?.trim();
    return (ausAntwort == null || ausAntwort.isEmpty) ? null : ausAntwort;
  }

  /// Speichert einen geänderten Vorgang (Upsert über die Referenz).
  Future<void> aktualisiere(Vorgang vorgang) => _upsert(vorgang);

  /// Hinterlegt den angefangenen Ausfüllstand am Vorgang, [entwurf] `null`
  /// verwirft ihn. No-op, wenn die Referenz keinen Vorgang trifft.
  ///
  /// Läuft über den eigenen Backend-Weg statt über [_upsert]: Der Entwurf wird
  /// beim Tippen laufend geschrieben und darf dabei nicht den ganzen Vorgang
  /// aus der Sicht des Wizards zurückschreiben.
  ///
  /// Ein Fehlschlag bleibt **still** — anders als beim Speichern eines
  /// Vorgangs (§7.2). Der Entwurf ist eine Bequemlichkeit, kein Bestand: Der
  /// nächste Tastendruck versucht es in Sekunden erneut, und eine Snackbar im
  /// selben Takt wäre die lautere Störung. Was wirklich zählt, geht weiterhin
  /// über den gemeldeten Weg.
  Future<void> sichereEntwurf(String referenz, VorgangEntwurf? entwurf) async {
    final vorhanden = findeZuReferenz(referenz);
    if (vorhanden == null) return;
    _ersetzeImState(vorhanden.copyWith(entwurf: () => entwurf));
    try {
      await _datasource.setzeEntwurf(vorhanden.referenz, entwurf);
    } catch (_) {
      // siehe oben
    }
  }

  /// Ändert die Referenz eines Vorgangs (z. B. Tippfehler im Kennzeichen).
  /// Die Referenz ist der fachliche Schlüssel — ein Upsert unter der neuen
  /// Referenz würde ein Duplikat anlegen, deshalb läuft die Umbenennung über
  /// einen eigenen, konfliktgeprüften Backend-Schritt. Liefert bei Erfolg den
  /// umbenannten Vorgang, sonst eine anzeigbare Fehlermeldung.
  Future<({Vorgang? vorgang, String? fehler})> aendereReferenz(
    Vorgang vorgang,
    String neueReferenz,
  ) async {
    final neu = neueReferenz.trim();
    if (neu.isEmpty) {
      return (vorgang: null, fehler: 'Die Referenz darf nicht leer sein.');
    }
    if (Vorgang.gleicheReferenz(vorgang.referenz, neu)) {
      return (vorgang: vorgang, fehler: null);
    }
    if (findeZuReferenz(neu) != null) {
      return (
        vorgang: null,
        fehler: 'Die Referenz „$neu" gehört bereits einem anderen Vorgang.',
      );
    }
    try {
      final umbenannt = await _datasource.aendereReferenz(
        vorgang.referenz,
        neu,
      );
      if (umbenannt == null) {
        return (
          vorgang: null,
          fehler:
              'Der Vorgang „${vorgang.referenz}" ist im Speicher des '
              'Hintergrunddienstes nicht vorhanden; die Referenz kann nicht '
              'geändert werden.',
        );
      }
      emit([
        ...state.where(
          (v) => !Vorgang.gleicheReferenz(v.referenz, vorgang.referenz),
        ),
        umbenannt,
      ]);
      return (vorgang: umbenannt, fehler: null);
    } on ReferenzVergebenException {
      return (
        vorgang: null,
        fehler: 'Die Referenz „$neu" gehört bereits einem anderen Vorgang.',
      );
    } catch (_) {
      return (
        vorgang: null,
        fehler:
            'Die Referenz konnte nicht geändert werden. '
            'Läuft der Hintergrunddienst?',
      );
    }
  }

  /// Löscht den Vorgang mit der angegebenen Referenz endgültig (z. B.
  /// Fehlerfassung oder Test-Vorgang). No-op, wenn keiner passt.
  Future<void> loesche(String referenz) async {
    final neu = state
        .where(
          (vorhanden) => !Vorgang.gleicheReferenz(vorhanden.referenz, referenz),
        )
        .toList();
    if (neu.length == state.length) return;
    emit(neu);
    await _loescheImBackend(referenz);
  }

  /// Schließt den Vorgang ab (Versand erledigt). Statuswechsel auf „versendet"
  /// und das Hochzählen der laufenden Auftragsnummer passieren atomar in einer
  /// Backend-Transaktion (§4.8) — schlägt sie fehl, bleibt beides
  /// unverändert und der Aufrufer bekommt `false` zur Anzeige zurück.
  /// Bereits abgeschlossene Vorgänge zählen nicht erneut hoch.
  Future<bool> abschliessen(Vorgang vorgang) async {
    if (vorgang.status == VorgangStatus.versendet) return true;
    try {
      final abgeschlossen = await _datasource.abschliessenVorgang(
        vorgang.referenz,
      );
      if (abgeschlossen == null) return false;
      _ersetzeImState(abgeschlossen);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Wiederholt die fehlgeschlagene Operation aus einem gemeldeten
  /// Persistenzfehler („Erneut versuchen" in der Snackbar).
  Future<void> wiederhole(VorgangPersistenzFehler fehler) =>
      switch (fehler.aktion) {
        VorgangPersistenzAktion.laden => ladeErneut(),
        VorgangPersistenzAktion.speichern => _upsert(fehler.vorgang!),
        VorgangPersistenzAktion.loeschen => _loescheImBackend(fehler.referenz!),
      };

  /// Liefert den Vorgang zur Referenz, falls vorhanden (tolerant gegenüber
  /// Schreibweise und Whitespace).
  Vorgang? findeZuReferenz(String? referenz) {
    if (referenz == null || referenz.trim().isEmpty) return null;
    for (final vorgang in state) {
      if (Vorgang.gleicheReferenz(vorgang.referenz, referenz)) return vorgang;
    }
    return null;
  }

  Future<void> _upsert(Vorgang vorgang) async {
    _ersetzeImState(vorgang);
    try {
      // Nur den einen geänderten Vorgang schreiben, nicht die ganze Liste.
      await _datasource.upsertVorgang(vorgang);
    } catch (_) {
      // Der In-Memory-Stand bleibt gültig, aber der Nutzer muss erfahren, dass
      // er nach einem Neustart verloren wäre (§7.2).
      _fehler.melde(VorgangPersistenzMeldung.speichern(vorgang));
    }
  }

  Future<void> _loescheImBackend(String referenz) async {
    try {
      await _datasource.deleteVorgang(referenz);
    } catch (_) {
      _fehler.melde(VorgangPersistenzMeldung.loeschen(referenz));
    }
  }

  void _ersetzeImState(Vorgang vorgang) {
    emit([
      ...state.where(
        (vorhanden) =>
            !Vorgang.gleicheReferenz(vorhanden.referenz, vorgang.referenz),
      ),
      vorgang,
    ]);
  }
}
