import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Kopfzeile über den Jahrgängen: der Ausschnitt und „Alle übernehmen".
///
/// Der Schalter steht auf „nur zu prüfen", und das ist mit Bedacht die
/// Voreinstellung: Bei zweihundert Zeilen je Jahrgang ist die vollständige
/// Liste keine Prüfung, sondern nur der Beweis, dass keine stattgefunden hat.
/// Gezeigt wird zuerst, wozu ein Mensch etwas zu sagen hat.
class RegisterImportFilterLeiste extends StatelessWidget {
  final bool nurZuPruefen;

  /// Wie viele Zeilen der Filter übrig lässt — die Zahl steht am Schalter,
  /// damit er nicht wie eine leere Ansicht aussieht.
  final int zuPruefen;

  final int zeilenGesamt;
  final bool kannUebernehmen;
  final bool laufend;

  const RegisterImportFilterLeiste({
    super.key,
    required this.nurZuPruefen,
    required this.zuPruefen,
    required this.zeilenGesamt,
    this.kannUebernehmen = false,
    this.laufend = false,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterImportCubit>();
    return Row(
      spacing: 12,
      children: [
        FilterChip(
          selected: nurZuPruefen,
          onSelected: cubit.filtern,
          label: Text('nur zu prüfen ($zuPruefen)'),
        ),
        Expanded(
          child: Text(
            '$zeilenGesamt Zeilen in der Datei',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (laufend)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          FilledButton.icon(
            onPressed: kannUebernehmen ? () => _fragen(context) : null,
            icon: const Icon(Icons.library_add_check_outlined, size: 18),
            label: const Text('Alle übernehmen'),
          ),
      ],
    );
  }

  Future<void> _fragen(BuildContext context) async {
    final cubit = context.read<RegisterImportCubit>();
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Alle Jahrgänge übernehmen?',
      text:
          'Die $zeilenGesamt Zeilen dieser Datei werden in die '
          'Registerhistorie geschrieben. Zeilen, die schon darin stehen, '
          'bleiben unangetastet — die Datei überschreibt nie.',
      bestaetigung: 'Übernehmen',
    );
    if (!bestaetigt) return;
    await cubit.uebernehmen();
  }
}
