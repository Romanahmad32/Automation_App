import 'dart:async';

import 'package:automation_app/features/settings/presentation/widgets/register_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/sicherungs_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/vorlagen_ordner_feld.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sonderpfade bleiben eingeklappt. Aktive Abweichungen sind im Titelbereich
/// sichtbar, auch wenn die Formularwerte erst nachträglich geladen werden.
class AbweichendeOrdnerAufklapper extends StatefulWidget {
  static const felder = [
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
  StreamSubscription<Object?>? _abo;
  String _abweichungen = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = ReactiveForm.of(context, listen: false);
    if (form is! FormGroup) return;
    _abo?.cancel();
    _abweichungen = _namen(form);
    _abo = form.valueChanges.listen((_) {
      if (!mounted) return;
      setState(() => _abweichungen = _namen(form));
    });
  }

  String _namen(FormGroup form) => AbweichendeOrdnerAufklapper.felder
      .where(
        (name) =>
            ((form.control(name).value as String?) ?? '').trim().isNotEmpty,
      )
      .map(
        (name) => switch (name) {
          'vorlagenOrdner' => 'Vorlagen',
          'registerAblageOrdner' => 'Register',
          _ => 'Sicherungen für den Arbeitsplatzwechsel',
        },
      )
      .join(', ');

  @override
  void dispose() {
    _abo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const form = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: form,
        collapsedShape: form,
        title: const Text('Erweiterte Einstellungen'),
        subtitle: Text(
          _abweichungen.isEmpty
              ? 'Optional: einzelne Ablageorte abweichend festlegen.'
              : 'Abweichende Ablage aktiv: $_abweichungen. '
                    'Hier gelten eigene Pfade statt der automatischen Unterordner.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _abweichungen.isEmpty ? null : theme.colorScheme.error,
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
                'Ein eigener Pfad ersetzt den jeweiligen automatischen Unterordner. '
                'Leer lassen, um den gemeinsamen OneDrive-Ordner zu verwenden. '
                'Eine andere Sicherungsablage wird auch für den Arbeitsplatzwechsel verwendet; '
                'beide Rechner müssen dieselbe Ablage nutzen.',
                style: theme.textTheme.bodySmall,
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
