import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_word_fassung.dart';

/// Die Übergänge des Vollmacht-Dialogs (§4.11), rein: Aus dem Stand und einer
/// Antwort des Dienstes wird der nächste Stand. Was vorher geschieht — Word
/// anstoßen, den Vermerk speichern —, erledigt der `VollmachtCubit` und reicht
/// nur das Ergebnis herein. So bleibt im Cubit der Ablauf lesbar und hier, wie
/// der Dialog danach aussieht.
extension VollmachtStandUebergaenge on VollmachtStand {
  /// Die Seite zu [auftrag] ist da — oder ihr Fehler, den die Fläche an
  /// Stelle der Seite zeigt.
  VollmachtStand mitVorschau(
    VollmachtAuftrag auftrag,
    Either<Failure, VollmachtVorschau> antwort,
  ) => copyWith(
    vorschauLaedt: false,
    vorschauFuer: auftrag,
    vorschauNummer: vorschauNummer + 1,
    vorschau: switch (antwort) {
      Right(value: final vorschau) => vorschau,
      Left(value: final failure) => VollmachtVorschau(
        status: VollmachtVorschauStatus.fehler,
        meldung: failure.message,
      ),
    },
  );

  /// Word hat den Druck angenommen; [vermerkt] sagt, ob der Vermerk am
  /// Vorgang sitzt. Der Druck schrieb dieselbe Datei wie „In Word öffnen"
  /// neu und löschte sie danach — eine Word-Fassung gibt es nicht mehr.
  VollmachtStand nachDruck(
    VollmachtErgebnis ergebnis, {
    required bool vermerkt,
  }) => copyWith(
    phase: VollmachtPhase.abgeschlossen,
    warnungen: ergebnis.warnungen,
    wordFassung: () => null,
    abschluss: () => VollmachtAbschluss(
      weg: VollmachtAbschlussWeg.gedruckt,
      zeitpunkt: DateTime.now(),
      drucker: ergebnis.drucker ?? drucker?.name,
      vermerkt: vermerkt,
      warnungen: ergebnis.warnungen,
    ),
  );

  /// Die ausgefüllte Datei aus [ergebnis] ist in Word geöffnet — oder ließ
  /// sich nicht öffnen ([geoeffnet]). Der Dialog bleibt in der Eingabe (#174);
  /// ein gescheiterter Druck bringt seine Meldung als Fehler mit.
  VollmachtStand mitWordFassung(
    VollmachtErgebnis ergebnis,
    VollmachtAuftrag auftrag, {
    required bool geoeffnet,
  }) {
    final pfad = ergebnis.pfad;
    return copyWith(
      phase: VollmachtPhase.eingabe,
      wordFassungEntstanden: true,
      wordFassung: pfad == null
          ? null
          : () => VollmachtWordFassung(
              pfad: pfad,
              auftrag: auftrag,
              zeitpunkt: DateTime.now(),
              geoeffnet: geoeffnet,
            ),
      warnungen: ergebnis.warnungen,
      fehler:
          ergebnis.meldung ??
          (pfad == null ? 'Der Dienst nannte keine ausgefüllte Datei.' : null),
    );
  }

  /// Dieselbe Word-Fassung noch einmal geöffnet — auch aus dem Ergebnis
  /// heraus geht es damit zurück in die Eingabe.
  VollmachtStand wordFassungErneutGeoeffnet(VollmachtWordFassung fassung) =>
      copyWith(
        phase: VollmachtPhase.eingabe,
        abschluss: () => null,
        wordFassung: () => fassung.erneutGeoeffnet(DateTime.now()),
      );

  /// Der Anwalt bestätigt, dass er in Word gedruckt hat; [vermerkt] sagt, ob
  /// der Vermerk gespeichert ist.
  VollmachtStand inWordGedruckt({required bool vermerkt}) => copyWith(
    phase: VollmachtPhase.abgeschlossen,
    abschluss: () => VollmachtAbschluss(
      weg: VollmachtAbschlussWeg.inWord,
      zeitpunkt: DateTime.now(),
      vermerkt: vermerkt,
      warnungen: warnungen,
    ),
  );

  /// Ausfüllen oder Druck kam ohne Datei zurück — zurück in die Eingabe mit
  /// [meldung]. Auch eine Datei, die Word noch offen hält
  /// (`ZieldateiGesperrtException` im Dienst): Die Word-Fassung bleibt stehen.
  VollmachtStand ohneDatei(String? meldung) => copyWith(
    phase: VollmachtPhase.eingabe,
    fehler: meldung ?? 'Die Vollmacht wurde nicht erstellt.',
  );

  /// Aus dem Ergebnis: Der Vermerk ist zurückgenommen, die Eingaben stehen.
  VollmachtStand vermerkZurueckgenommen() => copyWith(
    phase: VollmachtPhase.eingabe,
    abschluss: () => null,
    hinweis:
        'Vermerk zurückgenommen — am Vorgang gilt die Vollmacht als nicht '
        'gedruckt.',
  );
}
