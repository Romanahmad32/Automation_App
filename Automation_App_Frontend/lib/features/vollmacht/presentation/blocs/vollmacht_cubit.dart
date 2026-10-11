import 'dart:async';

import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_art_ableitung.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/drucke_vollmacht.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/erstelle_vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/fuelle_vollmacht_aus.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/raeume_vollmacht_auf.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand_uebergaenge.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_vorbereitung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Der Ablauf des Vollmacht-Dialogs (§4.11): vorbelegen, Seite zeigen,
/// drucken, bei einem gescheiterten Druck in Word öffnen, den Druck am Vorgang
/// vermerken — und danach stehen lassen, was passiert ist (#164).
///
/// Vermerkt wird **nur**, was die App weiß: nach einem Druck, den Word
/// angenommen hat — oder nach „In Word öffnen", wenn der Anwalt es
/// ausdrücklich bestätigt. Ein gescheiterter Druck öffnet die Datei und
/// vermerkt nichts von selbst.
///
/// „In Word öffnen" ist eine Nebenhandlung (#174): Der Dialog bleibt in der
/// Eingabe, Art, Felder und Vorschau bleiben bedienbar. Was in Word entstand,
/// räumt [close] beim Dienst wieder ab.
///
/// Hier steht der Ablauf — was angestoßen wird und in welcher Reihenfolge; wie
/// der Stand danach aussieht, sagt `VollmachtStandUebergaenge`.
@injectable
class VollmachtCubit extends Cubit<VollmachtStand> {
  final VollmachtVorbereitung _vorbereitung;
  final LadeVollmachtVorlagen _ladeVorlagen;
  final ErstelleVollmachtVorschau _erstelleVorschau;
  final DruckeVollmacht _drucke;
  final FuelleVollmachtAus _fuelleAus;
  final RaeumeVollmachtAuf _raeumeAuf;
  final VorgangCubit _vorgaenge;

  /// Ob während einer laufenden Vorschau eine weitere bestellt wurde — sie
  /// läuft dann genau einmal, sobald die laufende fertig ist.
  bool _vorschauNachbestellt = false;

  VollmachtCubit(
    this._vorbereitung,
    this._ladeVorlagen,
    this._erstelleVorschau,
    this._drucke,
    this._fuelleAus,
    this._raeumeAuf,
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

    final eingabe = await _vorbereitung.eingabe(state);
    if (isClosed) return;
    emit(eingabe);
  }

  /// Wählt die Vorlagenart; „in Sachen" und „wegen" folgen, solange der
  /// Anwalt sie nicht selbst geändert hat. Die Vorschau folgt mit (#174): Eine
  /// andere Art ist ein anderes Formular, nicht nur ein veralteter Feldwert.
  void waehleArt(VollmachtArt art) {
    if (art == state.art) return;
    emit(
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
    unawaited(erstelleVorschau());
  }

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

  /// Fragt den Standarddrucker ab — einmal, angestoßen vom Dialog, sobald die
  /// Eingabe steht (`VollmachtStand.druckerFaellig`). Nicht in [starte]: Das
  /// Öffnen soll nicht auf einen Drucker warten, der nicht antwortet, und eine
  /// Ausgabe danach löschte die Meldung des Öffnens.
  Future<void> ladeDrucker() async {
    if (isClosed || !state.druckerFaellig) return;

    emit(state.copyWith(druckerLaedt: true));
    final drucker = await _vorbereitung.drucker();
    if (isClosed) return;
    emit(state.copyWith(druckerLaedt: false, drucker: drucker));
  }

  /// Erzeugt die Seite zu den aktuellen Feldern — die erste stößt der Dialog
  /// an, sobald sie fällig ist (`VollmachtStand.vorschauFaellig`), weitere
  /// [waehleArt] und der Anwalt. Bewusst nicht bei jedem Tastendruck: Eine
  /// Umwandlung belegt den Word-Thread, und der Druck wartet in derselben
  /// Schlange.
  ///
  /// Läuft schon eine, wird nachbestellt: Danach läuft genau eine weitere für
  /// den **dann** aktuellen Auftrag — nie zwei gleichzeitig, und keine für
  /// eine Art, die inzwischen wieder abgewählt ist.
  Future<void> erstelleVorschau() async {
    if (isClosed) return;
    if (state.vorschauLaedt) {
      _vorschauNachbestellt = true;
      return;
    }

    var auftrag = state.auftrag;
    while (auftrag != null && !state.vorlageFehlt) {
      _vorschauNachbestellt = false;
      emit(state.copyWith(vorschauLaedt: true));
      final antwort = await _erstelleVorschau(auftrag);
      if (isClosed) return;
      emit(state.mitVorschau(auftrag, antwort));
      final aktuell = state.auftrag;
      auftrag = _vorschauNachbestellt && aktuell != auftrag ? aktuell : null;
    }
    _vorschauNachbestellt = false;
  }

  /// Füllt aus und druckt. Hat Word den Auftrag angenommen, wird der Druck
  /// vermerkt und der Dialog zeigt das Ergebnis; sonst öffnet sich die Datei
  /// in Word. Auch aus dem Ergebnis heraus — „Erneut drucken".
  Future<void> drucke() => _fuehreAus(_drucke);

  /// Öffnet die Vollmacht in Word. Ist der Auftrag seit dem letzten Öffnen
  /// unverändert und liegt die Datei noch da, öffnet er dieselbe noch einmal
  /// — hakte Word beim ersten Mal, hilft so ein zweiter Klick. Sonst füllt er
  /// neu aus; hält Word die alte Fassung, sagt der Dienst das.
  Future<void> oeffneInWord() async {
    final fassung = state.wordFassung;
    if (_ausfuehrbar && fassung != null && fassung.auftrag == state.auftrag) {
      // False heißt meist: Die Datei ist weg — dann eben neu ausfüllen.
      final geoeffnet = await DateiOeffner.oeffne(fassung.pfad);
      if (isClosed) return;
      if (geoeffnet) {
        emit(state.wordFassungErneutGeoeffnet(fassung));
        return;
      }
    }
    await _fuehreAus(_fuelleAus);
  }

  /// „Als gedruckt vermerken" aus der Leiste unter den Feldern — erst, wenn
  /// eine Word-Fassung geöffnet wurde.
  Future<void> vermerkeAlsGedruckt() async {
    if (state.wordFassung == null) return;
    final vermerkt = await _vermerke(gedruckt: true);
    if (isClosed || vermerkt == null) return;
    emit(state.inWordGedruckt(vermerkt: vermerkt));
  }

  /// Aus dem Ergebnis, „Kein Blatt gekommen?" → „Erneut drucken". Der Vermerk
  /// des ersten Drucks stimmt dann nicht und geht vorher zurück; ein
  /// gelungener Neudruck setzt ihn wieder, ein gescheiterter nicht.
  Future<void> druckeErneut() => _nachKeinemBlatt(drucke);

  /// Aus dem Ergebnis, „Kein Blatt gekommen?" → „In Word öffnen" — ebenso
  /// ohne den Vermerk des ersten Drucks; danach steht wieder die Eingabe mit
  /// der Leiste, aus der er sich neu setzen lässt.
  Future<void> oeffneInWordErneut() => _nachKeinemBlatt(oeffneInWord);

  Future<void> _nachKeinemBlatt(Future<void> Function() schritt) async {
    if (state.abschluss?.vermerkt ?? false) {
      final zurueck = await _vermerke(gedruckt: false);
      if (isClosed) return;
      if (zurueck != true) {
        emit(state.copyWith(fehler: _vermerkBleibt));
        return;
      }
    }
    await schritt();
  }

  /// Aus dem Ergebnis: den gescheiterten Vermerk noch einmal versuchen.
  Future<void> vermerkeErneut() async {
    final abschluss = state.abschluss;
    if (abschluss == null) return;
    final vermerkt = await _vermerke(gedruckt: true);
    if (isClosed || vermerkt == null) return;
    emit(
      state.copyWith(
        abschluss: () => abschluss.mitVermerk(vermerkt),
        fehler: vermerkt ? null : _vermerkFehlt,
      ),
    );
  }

  /// Aus dem Ergebnis: Es kam kein Blatt. Der Vermerk geht zurück, die
  /// Eingaben bleiben stehen — der Anwalt kann es neu versuchen.
  Future<void> nimmVermerkZurueck() async {
    final zurueck = await _vermerke(gedruckt: false);
    if (isClosed || zurueck == null) return;
    emit(
      zurueck
          ? state.vermerkZurueckgenommen()
          : state.copyWith(fehler: _vermerkBleibt),
    );
  }

  /// Schließt der Dialog, räumt der Dienst die Word-Fassungen dieses Vorgangs
  /// ab (§8, #174) — nur, wenn hier eine entstand, und ohne darauf zu warten:
  /// Hält Word die Datei noch, bleibt sie still bis zur Startaufräumung
  /// liegen, und das Schließen hat dem Anwalt nichts zu melden.
  @override
  Future<void> close() {
    final referenz = state.vorgang?.referenz;
    if (!isClosed && state.wordFassungEntstanden && referenz != null) {
      unawaited(_raeumeAuf(referenz));
    }
    return super.close();
  }

  static const _vermerkFehlt = 'Der Vermerk konnte nicht gespeichert werden.';
  static const _vermerkBleibt = 'Der Vermerk ließ sich nicht zurücknehmen.';

  bool get _ausfuehrbar =>
      state.phase == VollmachtPhase.eingabe ||
      state.phase == VollmachtPhase.abgeschlossen;

  /// Null, wenn der Vorgang fehlt; sonst, ob der Vermerk gespeichert ist.
  Future<bool?> _vermerke({required bool gedruckt}) async {
    final referenz = state.vorgang?.referenz;
    if (referenz == null) return null;
    return _vorgaenge.vermerkeVollmacht(referenz, gedruckt: gedruckt);
  }

  Future<void> _fuehreAus(
    UseCase<VollmachtErgebnis, VollmachtAuftrag> schritt,
  ) async {
    final auftrag = state.auftrag;
    if (!_ausfuehrbar || auftrag == null || state.vorlageFehlt) return;

    emit(state.copyWith(phase: VollmachtPhase.arbeitet, abschluss: () => null));
    final antwort = await schritt(auftrag);
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
        await _nimmAn(ergebnis, auftrag);
    }
  }

  Future<void> _nimmAn(
    VollmachtErgebnis ergebnis,
    VollmachtAuftrag auftrag,
  ) async {
    switch (ergebnis.status) {
      case VollmachtErgebnisStatus.gedruckt:
        final vermerkt = await _vermerke(gedruckt: true) ?? false;
        if (isClosed) return;
        emit(state.nachDruck(ergebnis, vermerkt: vermerkt));
      case VollmachtErgebnisStatus.druckFehlgeschlagen ||
          VollmachtErgebnisStatus.ausgefuellt:
        // In Word öffnen und in der Eingabe bleiben — ein gescheiterter Druck
        // bringt seine Meldung als Fehler mit.
        final pfad = ergebnis.pfad;
        final geoeffnet = pfad != null && await DateiOeffner.oeffne(pfad);
        if (isClosed) return;
        emit(state.mitWordFassung(ergebnis, auftrag, geoeffnet: geoeffnet));
      case VollmachtErgebnisStatus.vorlageFehlt ||
          VollmachtErgebnisStatus.fehler:
        emit(state.ohneDatei(ergebnis.meldung));
        if (ergebnis.status == VollmachtErgebnisStatus.vorlageFehlt) {
          await pruefeVorlagen();
        }
    }
  }
}
