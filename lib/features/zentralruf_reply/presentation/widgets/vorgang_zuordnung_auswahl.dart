import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/tone_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Auswahl, welchem Vorgang die ausgewertete Zentralruf-Antwort zugeordnet wird
/// (Req. 3.3). Passt die Referenz der Antwort zu einem bekannten Vorgang, ist er
/// vorausgewählt; andernfalls kann der Anwalt den richtigen Vorgang von Hand
/// wählen oder „Neuen Vorgang anlegen" lassen — so landet die Antwort nicht in
/// einem falschen oder unnötig neu angelegten Vorgang.
///
/// Gesteuert über [value] (normalisierte Referenz eines Vorgangs oder
/// [neuerVorgangWert]); die Auswahl meldet das Elternformular über [onChanged].
class VorgangZuordnungAuswahl extends StatelessWidget {
  /// Sentinel-Wert der Option „Neuen Vorgang anlegen".
  static const String neuerVorgangWert = '__neuer_vorgang__';

  /// Referenz aus der ausgewerteten Antwort (für die automatische Vorauswahl).
  final String? antwortReferenz;

  /// Referenz des über den Fallback (Gegner-Kennzeichen + Unfalldatum)
  /// gefundenen Vorgangs — eine „wahrscheinliche Zuordnung", die der Anwalt
  /// vor dem Übernehmen bestätigen soll. Null ohne Fallback-Treffer.
  final String? vermuteteReferenz;

  /// Aktuell gewählter Wert: normalisierte Referenz eines Vorgangs oder
  /// [neuerVorgangWert].
  final String value;

  final ValueChanged<String> onChanged;

  const VorgangZuordnungAuswahl({
    super.key,
    required this.antwortReferenz,
    this.vermuteteReferenz,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        // Auf welchen Vorgang die aktuelle Auswahl tatsächlich hinausläuft –
        // bei „Neuen Vorgang anlegen" fällt sie auf die Referenz der Antwort
        // zurück (und legt nur dann neu an, wenn es dazu keinen Vorgang gibt).
        final aufloesung = value == neuerVorgangWert ? antwortReferenz : value;
        final ziel = getIt<VorgangCubit>().findeZuReferenz(aufloesung);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchableDropdown<String>(
              value: value,
              labelText: 'Zuordnen zu Vorgang',
              hintText: 'Vorgang suchen oder auswählen',
              helperText:
                  'Bestimmt, in welchem Vorgang die Antwort gespeichert wird.',
              helperMaxLines: 2,
              leadingIcon: const Icon(Icons.folder_open),
              entries: [
                const SearchableDropdownEntry<String>(
                  value: neuerVorgangWert,
                  label: '➕ Neuen Vorgang anlegen',
                ),
                for (final vorgang in vorgaenge)
                  SearchableDropdownEntry<String>(
                    value: Vorgang.normalizeReferenz(vorgang.referenz),
                    label: _label(vorgang),
                  ),
              ],
              onChanged: (gewaehlt) =>
                  onChanged(gewaehlt ?? neuerVorgangWert),
            ),
            const SizedBox(height: 8),
            _hinweis(theme, ziel),
          ],
        );
      },
    );
  }

  Widget _hinweis(ThemeData theme, Vorgang? ziel) {
    if (ziel == null) {
      // Es entsteht ein neuer Vorgang (kein passender vorhanden bzw. bewusst
      // gewählt).
      final ref = (antwortReferenz ?? '').trim();
      return ToneCard(
        accent: theme.colorScheme.tertiary,
        icon: Icons.add_circle_outline,
        text: ref.isEmpty
            ? 'Wird als neuer Vorgang gespeichert.'
            : 'Wird als neuer Vorgang gespeichert (Referenz „$ref").',
      );
    }

    final automatisch = antwortReferenz != null &&
        Vorgang.gleicheReferenz(ziel.referenz, antwortReferenz!);
    final mandant = ziel.mandantName?.trim();
    final mandantTeil =
        mandant != null && mandant.isNotEmpty ? ' — $mandant' : '';

    // Fallback-Treffer über Kennzeichen + Unfalldatum: nur eine wahrscheinliche
    // Zuordnung — deutlich als zu bestätigender Vorschlag kennzeichnen.
    final vermutet = !automatisch &&
        vermuteteReferenz != null &&
        Vorgang.gleicheReferenz(ziel.referenz, vermuteteReferenz!);
    if (vermutet) {
      return ToneCard(
        accent: theme.colorScheme.tertiary,
        icon: Icons.help_outline,
        text:
            'Wahrscheinliche Zuordnung über Kennzeichen und Unfalldatum: '
            'Vorgang „${ziel.referenz}"$mandantTeil — bitte vor dem '
            'Übernehmen prüfen.',
      );
    }

    return ToneCard(
      accent: theme.colorScheme.primary,
      icon: automatisch ? Icons.link : Icons.edit,
      text: automatisch
          ? 'Automatisch über die Referenz dem Vorgang '
                '„${ziel.referenz}"$mandantTeil zugeordnet.'
          : 'Manuell dem Vorgang „${ziel.referenz}"$mandantTeil zugeordnet.',
    );
  }

  String _label(Vorgang vorgang) {
    final teile = <String>[
      vorgang.referenz,
      if ((vorgang.mandantName ?? '').trim().isNotEmpty) vorgang.mandantName!,
    ];
    return '${teile.join(' · ')}  (${vorgang.status.displayName})';
  }
}
