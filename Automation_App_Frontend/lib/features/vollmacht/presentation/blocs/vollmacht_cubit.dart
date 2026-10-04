import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_art_ableitung.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/drucke_vollmacht.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/fuelle_vollmacht_aus.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_mandant.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Ablauf des Vollmacht-Dialogs (§4.11): vorbelegen, drucken, bei einem
/// gescheiterten Druck in Word öffnen, den Druck am Vorgang vermerken.
///
/// Vermerkt wird **nur**, was die App weiß: nach einem Druck, den Word
/// angenommen hat — oder nach „In Word öffnen", wenn der Anwalt es
/// ausdrücklich bestätigt. Ein gescheiterter Druck öffnet die Datei und
/// vermerkt nichts von selbst.
@injectable
class VollmachtCubit extends Cubit<VollmachtStand> {
  final LadeVollmachtVorlagen _ladeVorlagen;
  final LadeVollmachtMandant _ladeMandant;
  final DruckeVollmacht _drucke;
  final FuelleVollmachtAus _fuelleAus;
  final VorgangCubit _vorgaenge;

  VollmachtCubit(
    this._ladeVorlagen,
    this._ladeMandant,
    this._drucke,
    this._fuelleAus,
    this._vorgaenge,
  ) : super(const VollmachtStand());

  /// Belegt den Dialog zu [vorgang] vor. [katalog] ist der Sachgebietskatalog
  /// für die Ableitung der Vorlagenart — leer, wenn er nicht geladen ist; dann
  /// zählt die Abteilung.
  Future<void> starte(Vorgang vorgang, List<Sachgebiet> katalog) async {
    final art = VollmachtArtAbleitung.zuVorgang(
      katalog,
      rechtsgebiet: vorgang.rechtsgebiet,
      abteilung: vorgang.abteilung,
    );
    emit(VollmachtStand(vorgang: vorgang, art: art));

    final vorlagenAbruf = _ladeVorlagen(const NoParams());
    Mandant? mandant;
    var lage = VollmachtMandantLage.keinerZugeordnet;
    String? fehler;
    final mandantId = vorgang.mandantId;
    if (mandantId != null) {
      final abruf = await _ladeMandant(mandantId);
      if (abruf case Right(value: final gefunden?)) {
        mandant = gefunden;
        lage = VollmachtMandantLage.geladen;
      } else {
        lage = VollmachtMandantLage.nichtGefunden;
        if (abruf case Left(value: final failure)) fehler = failure.message;
      }
    }
    final vorlagen = await vorlagenAbruf;
    if (isClosed) return;

    emit(
      state.copyWith(
        phase: VollmachtPhase.eingabe,
        kopfdaten: VollmachtVorbelegung.fuer(
          vorgang: vorgang,
          mandant: mandant,
          art: art,
        ),
        mandantLage: lage,
        // Ohne Stand bleibt der Druck möglich: Eine fehlende Vorlage meldet
        // dann der Dienst selbst.
        vorlagen: switch (vorlagen) {
          Right(value: final stand) => stand,
          _ => null,
        },
        fehler: fehler,
      ),
    );
  }

  /// Wählt die Vorlagenart; „in Sachen" und „wegen" folgen, solange der
  /// Anwalt sie nicht selbst geändert hat.
  void waehleArt(VollmachtArt art) => emit(
    state.copyWith(
      art: art,
      kopfdaten: VollmachtVorbelegung.nachziehen(
        altArt: state.art,
        alt: state.kopfdaten,
        neuArt: art,
        neu: state.kopfdaten,
      ),
    ),
  );

  /// Übernimmt die Eingabe; abgeleitete Zeilen folgen, solange unberührt.
  void aendereKopfdaten(VollmachtKopfdaten neu) => emit(
    state.copyWith(
      kopfdaten: VollmachtVorbelegung.nachziehen(
        altArt: state.art,
        alt: state.kopfdaten,
        neuArt: state.art,
        neu: neu,
      ),
    ),
  );

  /// Prüft den Vorlagenordner erneut — nachdem der Anwalt eine Datei abgelegt hat.
  Future<void> pruefeVorlagen() async {
    final abruf = await _ladeVorlagen(const NoParams());
    if (isClosed) return;
    switch (abruf) {
      case Right(value: final stand):
        emit(state.copyWith(vorlagen: stand));
      case Left(value: final failure):
        emit(state.copyWith(fehler: failure.message));
    }
  }

  /// Füllt aus und druckt. Hat Word den Auftrag angenommen, wird der Druck
  /// vermerkt und der Dialog schließt; sonst öffnet sich die Datei in Word.
  Future<void> drucke() => _fuehreAus(_drucke);

  /// Füllt nur aus und öffnet die Datei in Word.
  Future<void> oeffneInWord() => _fuehreAus(_fuelleAus);

  /// Bestätigung aus der Rückfrage nach dem Öffnen in Word.
  Future<void> vermerkeAlsGedruckt() async {
    final referenz = state.vorgang?.referenz;
    if (referenz == null) return;
    final vermerkt = await _vorgaenge.vermerkeVollmacht(
      referenz,
      gedruckt: true,
    );
    if (isClosed) return;
    emit(
      vermerkt
          ? state.copyWith(
              phase: VollmachtPhase.abgeschlossen,
              abschluss: 'Vollmacht am Vorgang als gedruckt vermerkt.',
            )
          : state.copyWith(
              fehler: 'Der Vermerk konnte nicht gespeichert werden.',
            ),
    );
  }

  Future<void> _fuehreAus(
    UseCase<VollmachtErgebnis, VollmachtAuftrag> schritt,
  ) async {
    final vorgang = state.vorgang;
    final art = state.art;
    if (!state.bereit || vorgang == null || art == null) return;

    emit(state.copyWith(phase: VollmachtPhase.arbeitet));
    final antwort = await schritt(
      VollmachtAuftrag(
        art: art,
        referenz: vorgang.referenz,
        kopfdaten: state.kopfdaten,
      ),
    );
    if (isClosed) return;

    switch (antwort) {
      case Left(value: final failure):
        emit(
          state.copyWith(
            phase: VollmachtPhase.eingabe,
            fehler: failure.message,
          ),
        );
      case Right(value: final ergebnis):
        await _nimmAn(ergebnis, vorgang.referenz);
    }
  }

  Future<void> _nimmAn(VollmachtErgebnis ergebnis, String referenz) async {
    switch (ergebnis.status) {
      case VollmachtErgebnisStatus.gedruckt:
        final vermerkt = await _vorgaenge.vermerkeVollmacht(
          referenz,
          gedruckt: true,
        );
        if (isClosed) return;
        emit(
          state.copyWith(
            phase: VollmachtPhase.abgeschlossen,
            warnungen: ergebnis.warnungen,
            abschluss: _gedrucktText(vermerkt, ergebnis.warnungen),
            abschlussOhneMakel: vermerkt && ergebnis.warnungen.isEmpty,
          ),
        );
      case VollmachtErgebnisStatus.druckFehlgeschlagen ||
          VollmachtErgebnisStatus.ausgefuellt:
        final pfad = ergebnis.pfad;
        final geoeffnet = pfad != null && await DateiOeffner.oeffne(pfad);
        if (isClosed) return;
        emit(
          state.copyWith(
            phase: VollmachtPhase.inWordGeoeffnet,
            pfad: pfad,
            geoeffnet: geoeffnet,
            warnungen: ergebnis.warnungen,
            fehler: ergebnis.meldung,
          ),
        );
      case VollmachtErgebnisStatus.vorlageFehlt ||
          VollmachtErgebnisStatus.fehler:
        emit(
          state.copyWith(
            phase: VollmachtPhase.eingabe,
            fehler: ergebnis.meldung ?? 'Die Vollmacht wurde nicht erstellt.',
          ),
        );
        if (ergebnis.status == VollmachtErgebnisStatus.vorlageFehlt) {
          await pruefeVorlagen();
        }
    }
  }

  static String _gedrucktText(bool vermerkt, List<String> warnungen) {
    final teile = [
      vermerkt
          ? 'Vollmacht an den Drucker gegeben und am Vorgang vermerkt.'
          : 'Vollmacht an den Drucker gegeben — der Vermerk am Vorgang '
                'konnte nicht gespeichert werden.',
      if (warnungen.isNotEmpty)
        'Nicht ersetzt: ${warnungen.map((w) => '{{$w}}').join(', ')}.',
    ];
    return teile.join(' ');
  }
}
