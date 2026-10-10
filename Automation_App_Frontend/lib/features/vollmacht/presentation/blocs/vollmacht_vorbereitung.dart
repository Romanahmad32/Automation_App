import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_mandant.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:injectable/injectable.dart';

/// Was der Vollmacht-Dialog beim Öffnen holt (§4.11): den Mandanten zum
/// Vorgang und den Stand der Vorlagen, parallel — daraus wird der Zustand, mit
/// dem der Dialog in die Eingabe geht. Den Standarddrucker holt [drucker]
/// getrennt davon, erst wenn die Eingabe steht: Ein Netzwerkdrucker, der
/// nicht antwortet, hielte das Öffnen sonst bis zum Timeout auf.
///
/// Nichts davon hält den Dialog auf: Ohne Vorlagenstand meldet eine fehlende
/// Vorlage der Dienst selbst, ein nicht abfragbarer Drucker wird nur genannt,
/// ein nicht ladbarer Mandant lässt die Felder leer und wird gemeldet.
@injectable
class VollmachtVorbereitung {
  final LadeVollmachtVorlagen _ladeVorlagen;
  final LadeVollmachtMandant _ladeMandant;
  final LadeVollmachtDrucker _ladeDrucker;

  VollmachtVorbereitung(
    this._ladeVorlagen,
    this._ladeMandant,
    this._ladeDrucker,
  );

  /// Der Eingabe-Zustand zu [start] (Phase `laedt`, mit Vorgang und Art).
  Future<VollmachtStand> eingabe(VollmachtStand start) async {
    final vorgang = start.vorgang;
    final vorlagenAbruf = _ladeVorlagen(const NoParams());
    Mandant? mandant;
    var lage = VollmachtMandantLage.keinerZugeordnet;
    String? fehler;
    final mandantId = vorgang?.mandantId;
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

    return start.copyWith(
      phase: VollmachtPhase.eingabe,
      kopfdaten: vorgang == null
          ? null
          : VollmachtVorbelegung.fuer(
              vorgang: vorgang,
              mandant: mandant,
              art: start.art,
            ),
      mandantLage: lage,
      vorlagen: switch (vorlagen) {
        Right(value: final stand) => stand,
        _ => null,
      },
      fehler: fehler,
    );
  }

  /// Der Standarddrucker; ließ er sich nicht abfragen, ein Drucker im Zustand
  /// „unbekannt" mit dem Grund — nie gar keiner, sonst fragte der Dialog
  /// immer wieder.
  Future<VollmachtDrucker> drucker() async =>
      switch (await _ladeDrucker(const NoParams())) {
        Right(value: final gefunden) => gefunden,
        Left(value: final failure) => VollmachtDrucker(
          zustand: VollmachtDruckerZustand.unbekannt,
          hinweis: failure.message,
        ),
      };
}
