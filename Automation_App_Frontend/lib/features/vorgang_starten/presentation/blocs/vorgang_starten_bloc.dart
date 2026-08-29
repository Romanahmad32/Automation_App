import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'vorgang_starten_event.dart';
part 'vorgang_starten_state.dart';

/// Orchestriert das Starten eines Vorgangs: regelt die Mandanten-Anlage bzw.
/// -Aktualisierung (§5.1), legt/aktualisiert den Vorgang als gemeinsame
/// Klammer (`VorgangCubit`) und füllt optional das Zentralruf-Onlineformular
/// vor. Die Dialog-Entscheidung trifft die View; hier läuft nur die Ausführung.
@injectable
class VorgangStartenBloc
    extends Bloc<VorgangStartenEvent, VorgangStartenState> {
  final UseCase<ZentralrufPrefillResult, ZentralrufRequest> _prefillForm;
  final UseCase<KanzleiSettings, NoParams> _getKanzleiSettings;
  final UseCase<Mandant, CreateMandantRequest> _createMandant;
  final UseCase<Mandant, Mandant> _updateMandant;
  final VorgangCubit _vorgaenge;

  VorgangStartenBloc(
    this._prefillForm,
    this._getKanzleiSettings,
    this._createMandant,
    this._updateMandant,
    this._vorgaenge,
  ) : super(VorgangStartenInitial()) {
    on<LadeDefaultsEvent>(_onLadeDefaults);
    on<SpeichereVorgangEvent>(_onSpeichereVorgang);
    on<SpeichereMandantEvent>(_onSpeichereMandant);
  }

  /// Speichert nur den Mandanten (Karten-Button), ohne den Vorgang anzulegen.
  Future<void> _onSpeichereMandant(
    SpeichereMandantEvent event,
    Emitter<VorgangStartenState> emit,
  ) async {
    emit(VorgangStartenLoading());
    if (event.neuerMandant != null) {
      final result = await _createMandant(event.neuerMandant!);
      switch (result) {
        case Left(value: final failure):
          emit(VorgangStartenError(failure.message));
        case Right(value: final mandant):
          emit(MandantGespeichert(mandant, warNeu: true));
      }
    } else if (event.aktualisierterMandant != null) {
      final result = await _updateMandant(event.aktualisierterMandant!);
      switch (result) {
        case Left(value: final failure):
          emit(VorgangStartenError(failure.message));
        case Right(value: final mandant):
          emit(MandantGespeichert(mandant, warNeu: false));
      }
    }
  }

  Future<void> _onLadeDefaults(
    LadeDefaultsEvent event,
    Emitter<VorgangStartenState> emit,
  ) async {
    final settings = await _ladeEinstellungen();
    if (settings != null) {
      emit(
        VorgangStartenDefaultsLoaded(
          auftragsnummer: settings.laufendeAuftragsnummer,
          abteilung: settings.abteilung,
        ),
      );
    }
    // Bei Fehler bleibt es bei den Formular-Standardwerten. Hochgezählt wird die
    // Auftragsnummer erst beim Abschluss des Vorgangs (§4.8).
  }

  Future<void> _onSpeichereVorgang(
    SpeichereVorgangEvent event,
    Emitter<VorgangStartenState> emit,
  ) async {
    emit(VorgangStartenLoading());
    final daten = event.daten;

    // 1. Mandant auflösen (anlegen / aktualisieren / nur verknüpfen). Was dabei
    // herauskommt, wird durchgereicht — bis in den Erfolgszustand und, wenn es
    // danach schiefgeht, in den Fehlerzustand: Die View braucht den Mandanten,
    // um ihn zu verknüpfen (§5.1). Gespeichert ist er ab hier so oder so.
    int? mandantId = event.verknuepfteMandantId;
    String? mandantName = daten.mandantName.isEmpty ? null : daten.mandantName;
    Mandant? gespeicherterMandant;

    if (event.neuerMandant != null) {
      final result = await _createMandant(event.neuerMandant!);
      switch (result) {
        case Left(value: final failure):
          emit(VorgangStartenError(failure.message));
          return;
        case Right(value: final mandant):
          gespeicherterMandant = mandant;
          mandantId = mandant.id;
          mandantName = mandant.anzeigename;
      }
    } else if (event.aktualisierterMandant != null) {
      final result = await _updateMandant(event.aktualisierterMandant!);
      switch (result) {
        case Left(value: final failure):
          emit(VorgangStartenError(failure.message));
          return;
        case Right(value: final mandant):
          gespeicherterMandant = mandant;
          mandantId = mandant.id;
          mandantName = mandant.anzeigename;
      }
    }

    // 2. Optional das Zentralruf-Formular vorbefüllen. Die zurückgegebene
    // (vom Backend normalisierte) Referenz hat Vorrang.
    var referenz = daten.referenz.trim();
    if (event.zentralrufAusfuellen && daten.istVerkehrsunfall) {
      final settings = await _ladeEinstellungen();
      final request = _zuRequest(daten, settings, mandantName);
      final result = await _prefillForm(request);
      switch (result) {
        case Left(value: final failure):
          // Der Mandant ist an dieser Stelle bereits im Register. Ginge er hier
          // verloren, hielte die Karte ihn weiter für neu und der nächste
          // Versuch bliebe am Namenskonflikt hängen (siehe FALLSTRICKE.md).
          emit(
            VorgangStartenError(
              failure.message,
              gespeicherterMandant: gespeicherterMandant,
            ),
          );
          return;
        case Right(value: final prefill):
          referenz = prefill.referenz;
      }
    }

    // 3. Vorgang als gemeinsame Klammer anlegen/aktualisieren.
    await _vorgaenge.registriereAnfrage(
      referenz,
      rechtsgebiet: daten.rechtsgebiet,
      mandantId: mandantId,
      mandantName: mandantName,
      unfallDatum: daten.istVerkehrsunfall ? daten.unfallDatumText : null,
      geschaedigtenKennzeichen: VorgangStartenDaten.leerZuNull(
        daten.mandantKennzeichen,
      ),
      unfallort: daten.istVerkehrsunfall
          ? VorgangStartenDaten.leerZuNull(daten.unfallort)
          : null,
      unfalluhrzeit: daten.istVerkehrsunfall
          ? VorgangStartenDaten.leerZuNull(daten.unfalluhrzeit)
          : null,
      polizeiVorgangsnummer: daten.istVerkehrsunfall
          ? VorgangStartenDaten.leerZuNull(daten.polizeiVorgangsnummer)
          : null,
    );

    emit(
      VorgangGespeichert(
        referenz: referenz,
        zentralrufAusgefuellt:
            event.zentralrufAusfuellen && daten.istVerkehrsunfall,
        gespeicherterMandant: gespeicherterMandant,
      ),
    );
  }

  Future<KanzleiSettings?> _ladeEinstellungen() async {
    final result = await _getKanzleiSettings(const NoParams());
    return switch (result) {
      Right(value: final settings) => settings,
      Left() => null,
    };
  }

  /// Baut den Zentralruf-Request aus den Eingaben. Der Unfalltag ist bei
  /// Verkehrsrecht durch die Validierung gesetzt, wenn dieser Pfad läuft.
  ZentralrufRequest _zuRequest(
    VorgangStartenDaten daten,
    KanzleiSettings? settings,
    String? mandantName,
  ) {
    return ZentralrufRequest(
      auftragsnummer: daten.auftragsnummer,
      auftragsjahr: daten.auftragsjahr,
      abteilung: daten.abteilung,
      kennzeichenSchaediger: daten.kennzeichenGegner.toUpperCase(),
      schadentag: daten.unfalltag ?? DateTime.now(),
      referenz: daten.referenz.trim().isEmpty ? null : daten.referenz.trim(),
      geschaedigter: daten.hatMandantDaten
          ? ZentralrufGeschaedigter(
              name: mandantName ?? daten.mandantName,
              strasseHausnummer: daten.strasseHausnummer,
              postleitzahl: daten.postleitzahl,
              ort: daten.ort,
              kennzeichen: daten.mandantKennzeichen.toUpperCase(),
            )
          : null,
      anfrager: settings == null ? null : _zuAnfrager(settings),
    );
  }

  ZentralrufAnfrager _zuAnfrager(KanzleiSettings settings) =>
      ZentralrufAnfrager(
        personentyp: settings.personentyp,
        name: settings.name,
        strasseHausnummer: settings.strasseHausnummer,
        postleitzahl: settings.postleitzahl,
        ort: settings.ort,
        emailAdresse: settings.emailAdresse,
        telefonnummer: settings.telefonnummer,
      );
}
