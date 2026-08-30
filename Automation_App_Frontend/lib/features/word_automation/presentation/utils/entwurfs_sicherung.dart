import 'dart:async';

import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';

/// Der Takt, in dem der angefangene Ausfüllstand am Vorgang landet.
///
/// Steht neben dem `WizardCubit` statt in ihm, weil hier eigener veränderlicher
/// Zustand liegt, der nichts mit dem Wizard-Zustand zu tun hat: ein laufender
/// Zeitgeber und die Marke „schon bestätigt". Beides ist Buchführung über die
/// *Ablage*, nicht über das, was der Anwalt sieht — und beides lässt sich so
/// einzeln prüfen, ohne einen Cubit aufzubauen.
///
/// Die Ablage läuft über den app-weiten [VorgangCubit] statt über das
/// Repository direkt: Sonst hielte dessen Liste weiter den Vorgang **ohne** den
/// gerade gesicherten Stand, und der nächste Einstieg böte einen veralteten an.
class EntwurfsSicherung {
  final VorgangCubit _vorgaenge;

  Timer? _takt;

  /// Ob der aktuelle Stand bereits **bestätigt** ist (ein Dokument daraus
  /// erzeugt). Dann wird nichts mehr abgelegt: Der Rückfluss hat den Entwurf im
  /// selben Atemzug am Vorgang gelöscht, und eine Sicherung danach brächte ihn
  /// als Angebot zurück, das nichts Neues enthält. Jede weitere Eingabe hebt
  /// die Marke wieder auf ([plane]).
  bool _bestaetigt = false;

  /// Wie lange nach der letzten Änderung gewartet wird, bevor der Entwurf zum
  /// Dienst geht. Das Formular meldet seinen Tippstand bereits entprellt; hier
  /// bündelt der Takt zusätzlich die Schadenspositionen, die bei jedem Zeichen
  /// melden.
  static const verzoegerung = Duration(seconds: 2);

  EntwurfsSicherung(this._vorgaenge);

  void markiereBestaetigt() => _bestaetigt = true;

  /// Legt den Stand **sofort** ab. Ohne [referenz] fehlt der Ablageort — freie
  /// Erfassung hält keinen Entwurf (bewusste Abgrenzung des ersten Wurfs).
  void jetzt({
    required String? referenz,
    required Map<String, String>? werte,
    required DamageListing? aufstellung,
  }) {
    _takt?.cancel();
    if (referenz == null || werte == null || _bestaetigt) return;

    final entwurf = VorgangEntwurf(
      gespeichertAm: DateTime.now(),
      feldWerte: werte,
      schadensaufstellung: aufstellung,
    );
    if (entwurf.istLeer) return;
    _vorgaenge.sichereEntwurf(referenz, entwurf);
  }

  /// Startet den Takt neu. Ohne Vorgang gibt es keinen Ablageort — dann braucht
  /// es auch keinen Zeitgeber. (Und kein Widget-Test der freien Erfassung endet
  /// mit einem laufenden Timer, den er nicht bestellt hat.)
  void plane(void Function() sichern, {required bool hatVorgang}) {
    _bestaetigt = false;
    _takt?.cancel();
    if (!hatVorgang) return;
    _takt = Timer(verzoegerung, sichern);
  }

  void beende() => _takt?.cancel();
}
