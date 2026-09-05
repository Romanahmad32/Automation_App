import 'dart:async';

import 'package:automation_app/features/settings/presentation/widgets/register_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/sicherungs_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/vorlagen_ordner_feld.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die drei Einzelwahlen, die es vor dem einen Ordner für die App-Daten gab
/// (#103) — eingeklappt, aber erreichbar.
///
/// Wegzunehmen wären sie nicht: Ein Anwalt, dessen Vorlagen seit Jahren auf
/// einem Netzlaufwerk liegen, darf nicht ausgesperrt werden. Sichtbar sind sie
/// trotzdem nicht, denn im Regelfall gibt es nichts zu entscheiden — die drei
/// Ordner entstehen unter dem einen darüber.
///
/// Gestaltet wie die anderen aufklappbaren Flächen der App
/// (`nicht_verwendete_felder.dart`, `MailboxOriginaltextPanel`): eigene Karte,
/// Kartenform am `ExpansionTile`, kein `leading`-Icon.
///
/// **Zugeklappt nur, solange alle drei leer sind.** Wer einen dieser Ordner
/// gesetzt hat, soll ihn sehen, ohne ihn zu suchen — sonst sieht der Reiter
/// aus, als gälte allein der Ordner oben, während in Wahrheit ein anderer
/// gewinnt. Der Zustand ist bewusst **einbahnig**: Einmal aufgeklappt, bleibt
/// offen. Wer das letzte der drei Felder leert, stünde sonst mitten im
/// Arbeiten vor einer Fläche, die sich unter ihm zuklappt.
class AbweichendeOrdnerAufklapper extends StatefulWidget {
  /// Die Felder, deren Inhalt darüber entscheidet, ob offen begonnen wird.
  static const List<String> felder = [
    'vorlagenOrdner',
    'registerAblageOrdner',
    'sicherungsAblageOrdner',
  ];

  const AbweichendeOrdnerAufklapper({super.key});

  @override
  State<AbweichendeOrdnerAufklapper> createState() =>
      AbweichendeOrdnerAufklapperState();
}

class AbweichendeOrdnerAufklapperState
    extends State<AbweichendeOrdnerAufklapper> {
  /// Dieselbe Rundung wie die Karte, ohne eigene Linie: Das `ExpansionTile`
  /// zöge im aufgeklappten Zustand sonst seine Vorgabe-Trennlinien quer über
  /// den Kartenrahmen.
  static const RoundedRectangleBorder kartenForm = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    side: BorderSide.none,
  );

  StreamSubscription<Object?>? _abo;
  bool _offen = false;

  /// Die Werte kommen **nach** dem ersten Aufbau: `AppSettingsView` füllt das
  /// Formular erst, wenn der Bloc geladen hat. Ein einmal im `initState`
  /// gelesener Stand wäre deshalb immer leer und der Aufklapper immer zu.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = ReactiveForm.of(context, listen: false);
    if (form is! FormGroup) return;

    _abo?.cancel();
    // Ohne setState: Das hier läuft vor dem ersten Aufbau dieses Widgets.
    _offen = _offen || _gefuellt(form);
    _abo = form.valueChanges.listen((_) {
      if (_offen || !_gefuellt(form) || !mounted) return;
      setState(() => _offen = true);
    });
  }

  @override
  void dispose() {
    _abo?.cancel();
    super.dispose();
  }

  bool _gefuellt(FormGroup form) => AbweichendeOrdnerAufklapper.felder.any(
    (name) => ((form.control(name).value as String?) ?? '').trim().isNotEmpty,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Der Schlüssel ist der ganze Trick: `initiallyExpanded` liest das
        // `ExpansionTile` nur beim ersten Aufbau. Wechselt der Wert, muss ein
        // neues her — sonst bliebe die Fläche zu, obwohl ein Ordner darin
        // steht.
        key: ValueKey(_offen),
        initiallyExpanded: _offen,
        shape: kartenForm,
        collapsedShape: kartenForm,
        title: const Text('Abweichende Ordner festlegen'),
        subtitle: Text(
          'Nur nötig, wenn Vorlagen, Register oder Sicherungen woanders '
          'liegen sollen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                'Was hier steht, gewinnt gegen den Ordner oben. Leer heißt: '
                'die App leitet den Ordner von ihm ab.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const VorlagenOrdnerFeld(),
              const RegisterAblageFelder(),
              const SicherungsAblageFelder(),
            ],
          ),
        ],
      ),
    );
  }
}
