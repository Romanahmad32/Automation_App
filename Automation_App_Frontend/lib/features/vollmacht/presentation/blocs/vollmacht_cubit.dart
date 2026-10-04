import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_art_ableitung.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/drucke_vollmacht.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/erstelle_vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/fuelle_vollmacht_aus.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
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
@injectable
class VollmachtCubit extends Cubit<VollmachtStand> {
  final VollmachtVorbereitung _vorbereitung;
  final LadeVollmachtVorlagen _ladeVorlagen;
  final ErstelleVollmachtVorschau _erstelleVorschau;
  final DruckeVollmacht _drucke;
  final FuelleVollmachtAus _fuelleAus;
  final VorgangCubit _vorgaenge;

  VollmachtCubit(
    this._vorbereitung,
    this._ladeVorlagen,
    this._erstelleVorschau,
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

    final eingabe = await _vorbereitung.eingabe(state);
    if (isClosed) return;
    emit(eingabe);
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

  /// Erzeugt die Seite zu den aktuellen Feldern — die erste stößt der Dialog
  /// an, sobald sie fällig ist (`VollmachtStand.vorschauFaellig`), jede
  /// weitere der Anwalt. Bewusst nicht bei jedem Tastendruck: Eine Umwandlung
  /// belegt den Word-Thread, und der Druck wartet in derselben Schlange.
  Future<void> erstelleVorschau() async {
    final auftrag = _auftrag();
    if (isClosed || auftrag == null) return;
    if (state.vorschauLaedt || state.vorlageFehlt) return;

    emit(state.copyWith(vorschauLaedt: true));
    final antwort = await _erstelleVorschau(auftrag);
    if (isClosed) return;
    emit(
      state.copyWith(
        vorschauLaedt: false,
        vorschauFuer: auftrag,
        vorschauNummer: state.vorschauNummer + 1,
        vorschau: switch (antwort) {
          Right(value: final vorschau) => vorschau,
          Left(value: final failure) => VollmachtVorschau(
            status: VollmachtVorschauStatus.fehler,
            meldung: failure.message,
          ),
        },
      ),
    );
  }

  /// Füllt aus und druckt. Hat Word den Auftrag angenommen, wird der Druck
  /// vermerkt und der Dialog zeigt das Ergebnis; sonst öffnet sich die Datei
  /// in Word. Auch aus dem Ergebnis heraus — „Erneut drucken".
  Future<void> drucke() => _fuehreAus(_drucke);

  /// Füllt nur aus und öffnet die Datei in Word.
  Future<void> oeffneInWord() => _fuehreAus(_fuelleAus);

  /// Bestätigung aus der Rückfrage nach dem Öffnen in Word.
  Future<void> vermerkeAlsGedruckt() async {
    final vermerkt = await _vermerke(gedruckt: true);
    if (isClosed || vermerkt == null) return;
    emit(
      state.copyWith(
        phase: VollmachtPhase.abgeschlossen,
        abschluss: () => VollmachtAbschluss(
          weg: VollmachtAbschlussWeg.inWord,
          zeitpunkt: DateTime.now(),
          vermerkt: vermerkt,
          warnungen: state.warnungen,
        ),
      ),
    );
  }

  /// Aus dem Ergebnis, „Kein Blatt gekommen?" → „Erneut drucken". Der Vermerk
  /// des ersten Drucks stimmt dann nicht und geht vorher zurück; ein
  /// gelungener Neudruck setzt ihn wieder, ein gescheiterter nicht.
  Future<void> druckeErneut() => _nachKeinemBlatt(drucke);

  /// Aus dem Ergebnis, „Kein Blatt gekommen?" → „In Word öffnen" — ebenso
  /// ohne den Vermerk des ersten Drucks; die Rückfrage danach setzt ihn neu.
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
          ? state.copyWith(
              phase: VollmachtPhase.eingabe,
              abschluss: () => null,
              hinweis:
                  'Vermerk zurückgenommen — am Vorgang gilt die Vollmacht '
                  'als nicht gedruckt.',
            )
          : state.copyWith(fehler: _vermerkBleibt),
    );
  }

  static const _vermerkFehlt = 'Der Vermerk konnte nicht gespeichert werden.';
  static const _vermerkBleibt = 'Der Vermerk ließ sich nicht zurücknehmen.';

  /// Null, wenn der Vorgang fehlt; sonst, ob der Vermerk gespeichert ist.
  Future<bool?> _vermerke({required bool gedruckt}) async {
    final referenz = state.vorgang?.referenz;
    if (referenz == null) return null;
    return _vorgaenge.vermerkeVollmacht(referenz, gedruckt: gedruckt);
  }

  VollmachtAuftrag? _auftrag() {
    final vorgang = state.vorgang;
    final art = state.art;
    if (vorgang == null || art == null) return null;
    return VollmachtAuftrag(
      art: art,
      referenz: vorgang.referenz,
      kopfdaten: state.kopfdaten,
    );
  }

  Future<void> _fuehreAus(
    UseCase<VollmachtErgebnis, VollmachtAuftrag> schritt,
  ) async {
    final auftrag = _auftrag();
    final ausfuehrbar =
        state.phase == VollmachtPhase.eingabe ||
        state.phase == VollmachtPhase.abgeschlossen;
    if (!ausfuehrbar || auftrag == null || state.vorlageFehlt) return;

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
        await _nimmAn(ergebnis);
    }
  }

  Future<void> _nimmAn(VollmachtErgebnis ergebnis) async {
    switch (ergebnis.status) {
      case VollmachtErgebnisStatus.gedruckt:
        final vermerkt = await _vermerke(gedruckt: true) ?? false;
        if (isClosed) return;
        emit(
          state.copyWith(
            phase: VollmachtPhase.abgeschlossen,
            warnungen: ergebnis.warnungen,
            abschluss: () => VollmachtAbschluss(
              weg: VollmachtAbschlussWeg.gedruckt,
              zeitpunkt: DateTime.now(),
              drucker: ergebnis.drucker ?? state.drucker?.name,
              vermerkt: vermerkt,
              warnungen: ergebnis.warnungen,
            ),
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
}
