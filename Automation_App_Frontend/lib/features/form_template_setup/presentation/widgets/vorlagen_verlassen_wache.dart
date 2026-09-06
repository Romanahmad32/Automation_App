import 'dart:async';

import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_entwurf.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';

/// Hält den Vorlageneditor fest, solange ungespeicherte Änderungen darin
/// stehen: Wer die Seite verlässt, wird gefragt, ob er sie verwerfen will
/// (§1.3, „Erfasste Daten gehen nicht verloren").
///
/// Die Wache legt beim Aufgehen einen [VorlagenEntwurf] als Schnappschuss ab
/// und vergleicht ihn mit dem jeweils aktuellen Stand. Sie umschließt den
/// Seiteninhalt, weil `PopScope` an der Route hängt — damit gilt sie für
/// **jeden** Weg hinaus: den Abbrechen-Knopf, den Zurück-Pfeil der AppBar und
/// die Zurück-Geste des Systems.
///
/// Nicht erfasst ist bewusst das Speichern: `Navigator.pop` fragt `PopScope`
/// gar nicht erst (nur `maybePop` und die Systemgeste tun das), und genau so
/// soll es sein — nach erfolgreichem Speichern gibt es nichts mehr zu
/// verwerfen. Wer den Erfolgsweg der Seite auf `maybePop` umstellt, bekommt
/// den Verwerfen-Dialog also nach dem Speichern zu sehen; `vorlagen_verlassen_test.dart`
/// hält das fest.
class VorlagenVerlassenWache extends StatefulWidget {
  /// Sperrt jeden Weg hinaus, solange die Vorlage geschrieben wird — kein Pop
  /// und **keine** Rückfrage.
  ///
  /// Das ist kein Feinschliff, sondern verhindert einen stillen Datenfehler:
  /// Stünde der Verwerfen-Dialog noch offen, wenn der Erfolg eintrifft, träfe
  /// das `Navigator.pop(true)` der Seite die **oberste** Route — den Dialog.
  /// `bestaetigen` löste damit als „verwerfen" auf, die Wache schlösse die
  /// Seite mit `false`, und die Übersicht bliebe nach einem erfolgreichen
  /// Speichern auf dem alten Stand stehen. Kein Fehler, keine Meldung, nur die
  /// fehlende Zeile in der Liste. Solange nichts aufgeht, kann das nicht
  /// passieren.
  final bool gesperrt;

  /// Der veränderliche Stand des Editors: Vorlagenname und Feldnamen aus der
  /// `FormGroup`, dazu Feldliste und die beiden Word-Pfade. Es ist **dieselbe**
  /// Instanz, die die Seite ändert — die Wache sieht damit jede Änderung, ohne
  /// dass sie ihr gemeldet werden müsste.
  ///
  /// Die `FormGroup` wird **nicht** nur gelesen, sondern auch belauscht: Tippen
  /// im Namensfeld baut die Seite nicht neu auf, und ohne den Horcher stünde
  /// `canPop` auf dem Stand des letzten Aufbaus — die Umbenennung ginge beim
  /// Verlassen wortlos verloren.
  final VorlagenBearbeitung bearbeitung;

  final Widget child;

  const VorlagenVerlassenWache({
    super.key,
    required this.bearbeitung,
    required this.gesperrt,
    required this.child,
  });

  @override
  State<VorlagenVerlassenWache> createState() => VorlagenVerlassenWacheState();
}

class VorlagenVerlassenWacheState extends State<VorlagenVerlassenWache> {
  /// Der Stand beim Aufgehen der Seite. Die Wache wird im ersten Aufbau der
  /// Detailseite erzeugt, also nach deren `initState` — die `FormGroup` steht
  /// hier fertig.
  late final VorlagenEntwurf _beimOeffnen;

  StreamSubscription<Map<String, Object?>?>? _horcher;

  /// Verhindert einen zweiten Dialog, während der erste offen steht: Der
  /// Zurück-Pfeil bleibt drückbar, und jeder Druck löst einen Pop-Versuch aus.
  bool _frageLaeuft = false;

  @override
  void initState() {
    super.initState();
    _beimOeffnen = _aktuell;
    _horcher = widget.bearbeitung.formGroup.valueChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _horcher?.cancel();
    super.dispose();
  }

  VorlagenBearbeitung get _stand => widget.bearbeitung;

  VorlagenEntwurf get _aktuell => VorlagenEntwurf.aufnehmen(
    vorlagenname: _stand.formGroup.control('templateName').value as String?,
    pfadOhneAuflistung: _stand.pfadOhneAuflistung,
    pfadMitAuflistung: _stand.pfadMitAuflistung,
    fields: _stand.fields,
    feldname: _stand.feldname,
  );

  /// Ob der Editor etwas trägt, was noch nicht in der Datenbank steht.
  bool get ungespeichert => _aktuell != _beimOeffnen;

  Future<void> _beiPopVersuch(bool didPop, Object? ergebnis) async {
    if (didPop || _frageLaeuft || widget.gesperrt) return;
    _frageLaeuft = true;
    final verwerfen = await bestaetigen(
      context,
      icon: Icons.warning_amber_rounded,
      titel: 'Änderungen verwerfen?',
      text:
          'Diese Vorlage hat ungespeicherte Änderungen. Beim Verlassen gehen '
          'sie verloren.',
      bestaetigung: 'Verwerfen',
      abbruch: 'Weiter bearbeiten',
      destruktiv: true,
    );
    _frageLaeuft = false;
    if (!verwerfen || !mounted) return;
    // `false` und nicht `true`: Verworfen wurde nichts gespeichert, die
    // Übersicht braucht also kein Neuladen (siehe `form_template_row.dart`).
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.gesperrt && !ungespeichert,
      onPopInvokedWithResult: _beiPopVersuch,
      child: widget.child,
    );
  }
}
