import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/widgets/jahrgang_befund_karte.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_datei_auswahl.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_filter_leiste.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_zeilen_liste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die drei Bilder der Registerübernahme in einer Ansicht: Datei wählen,
/// Jahrgänge prüfen, Ergebnis lesen (§6.2). Bewusst eine Seite und kein
/// Assistent mit Schritten — der Bericht bleibt nach dem Übernehmen stehen, und
/// genau ihn will man danach noch einmal durchgehen.
class RegisterImportView extends StatelessWidget {
  final RegisterImportState state;

  /// Reicht die Anleitung den Jahrgang durch, den der Stand auf Tab 6
  /// vorschlägt.
  final int? vorgeschlagenerJahrgang;

  const RegisterImportView({
    super.key,
    required this.state,
    this.vorgeschlagenerJahrgang,
  });

  @override
  Widget build(BuildContext context) {
    final bericht = state.bericht;
    if (bericht == null) return _vorDerDatei(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _dateizeile(context),
        if (state.fehler != null) FehlerHinweis(nachricht: state.fehler!),
        RegisterImportFilterLeiste(
          nurZuPruefen: state.nurZuPruefen,
          zuPruefen: bericht.zuPruefenGesamt,
          zeilenGesamt: bericht.zeilenGesamt,
          kannUebernehmen: state.kannUebernehmen,
          laufend: state.laufend,
        ),
        if (state.bearbeitetAnzahl > 0)
          Text(
            '${state.bearbeitetAnzahl} Zeilen von Hand geändert',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Expanded(
          child: bericht.jahrgaenge.isEmpty
              ? Center(
                  child: Text(
                    'Die Datei enthält keinen Jahrgang. Über „Andere Datei" '
                    'lesen Sie sie im Urzustand neu ein.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              // ListView.builder über die Jahrgänge: gebaut wird nur, was zu
              // sehen ist. Die Zeilen eines Jahrgangs hängen darin
              // (`shrinkWrap`) — ein Jahrgang ist rund zweihundert Zeilen, und
              // der Filter zeigt zunächst nur die zu prüfenden.
              : ListView.builder(
                  itemCount: bericht.jahrgaenge.length,
                  itemBuilder: (_, i) => _jahrgang(bericht.jahrgaenge[i]),
                ),
        ),
      ],
    );
  }

  Widget _jahrgang(JahrgangBefund befund) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        JahrgangBefundKarte(
          befund: befund,
          uebernommen: state.istUebernommen(befund.jahrgang),
          kannUebernehmen: state.kannJahrgangUebernehmen(befund.jahrgang),
          laufend: state.laufend,
        ),
        RegisterImportZeilenListe(
          zeilen: befund.sichtbar(nurZuPruefen: state.nurZuPruefen),
          stand: state,
        ),
      ],
    ),
  );

  Widget _vorDerDatei(BuildContext context) {
    if (state.laufend) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            CircularProgressIndicator(),
            Text('Die Datei wird gelesen und geprüft …'),
          ],
        ),
      );
    }

    if (state.fehler != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          FehlerHinweis(nachricht: state.fehler!),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.read<RegisterImportCubit>().zuruecksetzen(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Andere Datei wählen'),
            ),
          ),
        ],
      );
    }

    return RegisterImportDateiAuswahl(
      vorgeschlagenerJahrgang: vorgeschlagenerJahrgang,
    );
  }

  Widget _dateizeile(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.description_outlined, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.dateiPfad ?? '',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton.icon(
          onPressed: () => context.read<RegisterImportCubit>().zuruecksetzen(),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Andere Datei'),
        ),
      ],
    );
  }
}
