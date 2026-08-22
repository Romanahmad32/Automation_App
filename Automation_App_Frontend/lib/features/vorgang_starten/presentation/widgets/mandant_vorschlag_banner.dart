import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Wiedererkennungs-Hinweis im Mandanten-Abschnitt: Passen die frei getippten
/// Eingaben (Name oder Kennzeichen) zu einem gespeicherten Mandanten, schlägt
/// die App diesen mit „Übernehmen" vor — statt still ein Duplikat entstehen zu
/// lassen. Reagiert live auf die Formularwerte (`ReactiveFormConsumer`) und
/// verschwindet, sobald ein Mandant verknüpft ist oder nichts passt.
class MandantVorschlagBanner extends StatelessWidget {
  /// Alle Registereinträge, gegen die verglichen wird.
  final List<Mandant> mandanten;

  /// Übernimmt den vorgeschlagenen Mandanten (wie die Dropdown-Auswahl).
  final ValueChanged<Mandant> onUebernehmen;

  const MandantVorschlagBanner({
    super.key,
    required this.mandanten,
    required this.onUebernehmen,
  });

  String _wert(FormGroup form, String controlName) =>
      (form.control(controlName).value as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    if (mandanten.isEmpty) return const SizedBox.shrink();

    return ReactiveFormConsumer(
      builder: (context, form, child) {
        final vorschlaege = MandantErkennung.finde(
          mandanten: mandanten,
          vorname: _wert(form, 'mandantVorname'),
          nachname: _wert(form, 'mandantNachname'),
          kennzeichen: _wert(form, 'mandantKennzeichen'),
        );
        if (vorschlaege.isEmpty) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final tone = SoftTone.fromAccent(colorScheme.tertiary, colorScheme);
        return Card(
          margin: EdgeInsets.zero,
          color: tone.background,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_search_outlined, color: tone.foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vorschlaege.length == 1
                            ? 'Passt zu einem gespeicherten Mandanten:'
                            : 'Passt zu gespeicherten Mandanten:',
                        style: TextStyle(color: tone.foreground),
                      ),
                    ),
                  ],
                ),
                for (final vorschlag in vorschlaege)
                  MandantVorschlagZeile(
                    vorschlag: vorschlag,
                    foreground: tone.foreground,
                    onUebernehmen: () => onUebernehmen(vorschlag.mandant),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Eine Vorschlagszeile des [MandantVorschlagBanner]s: Anzeigename + Anschrift,
/// Begründung des Treffers und der Übernehmen-Button.
class MandantVorschlagZeile extends StatelessWidget {
  final MandantVorschlag vorschlag;
  final Color foreground;
  final VoidCallback onUebernehmen;

  const MandantVorschlagZeile({
    super.key,
    required this.vorschlag,
    required this.foreground,
    required this.onUebernehmen,
  });

  String get _anschrift {
    final mandant = vorschlag.mandant;
    final teile = [
      mandant.strasseHausnummer,
      '${mandant.postleitzahl} ${mandant.ort}'.trim(),
    ].where((teil) => teil.trim().isNotEmpty).toList();
    return teile.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _anschrift.isEmpty
                      ? vorschlag.mandant.anzeigename
                      : '${vorschlag.mandant.anzeigename} · $_anschrift',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  vorschlag.begruendung,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onUebernehmen,
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }
}
