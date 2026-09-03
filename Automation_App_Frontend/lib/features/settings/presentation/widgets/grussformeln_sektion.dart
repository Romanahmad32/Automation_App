import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/entfernen_rueckfrage.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_state.dart';
import 'package:automation_app/features/settings/presentation/widgets/grussformel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Verwaltung der Zusatzgrüße (§4.7, §7.1) — im Reiter
/// „E-Mail", neben den Textvorlagen, in die sie eingesetzt werden.
///
/// **Eine Liste von Textbausteinen, kein Merkmal von Personen.** Sie hängt an
/// keinem Mandanten und ordnet niemanden ein; gewählt wird sie je Mail beim
/// Verfassen. Wie viele es gibt, bestimmt der Anwalt.
class GrussformelnSektion extends StatelessWidget {
  const GrussformelnSektion({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<GrussformelnCubit>()..ladenWennNoetig(),
      child: const GrussformelnSektionInhalt(),
    );
  }
}

/// Der Abschnitt selbst, unter dem bereitgestellten [GrussformelnCubit].
class GrussformelnSektionInhalt extends StatelessWidget {
  const GrussformelnSektionInhalt({super.key});

  Future<void> _bearbeite(BuildContext context, Grussformel grussformel) {
    final cubit = context.read<GrussformelnCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) => GrussformelDialog(
        grussformel: grussformel,
        onSpeichern: cubit.speichere,
      ),
    );
  }

  /// Erst fragen, dann entfernen (§7.1, ergänzt am 03.09.2026): Der Gruß kommt
  /// nicht wieder, und das ✕ am Chip liegt einen Millimeter neben dem Chip
  /// selbst.
  Future<void> _entferne(BuildContext context, Grussformel gruss) async {
    final cubit = context.read<GrussformelnCubit>();
    final sicher = await EntfernenRueckfrage.gestellt(
      context,
      titel: 'Gruß entfernen?',
      text:
          '„${gruss.text}" wird aus dem Bestand gelöscht und steht beim '
          'Verfassen nicht mehr zur Auswahl. Bereits versendete Mails '
          'bleiben davon unberührt.',
    );
    if (sicher) await cubit.loesche(gruss.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrussformelnCubit, GrussformelnState>(
      builder: (context, stand) {
        return FormSection(
          icon: Icons.waving_hand_outlined,
          title: 'Zusatzgrüße',
          subtitle:
              'Zur Auswahl beim Verfassen — eingesetzt überall, wo eine '
              'Textvorlage den Platzhalter {{Zusatzgruß}} trägt. '
              'Textbausteine: sie hängen an keinem Mandanten.',
          trailing: stand.laedt
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          children: [
            if (stand.fehler != null)
              Text(
                stand.fehler!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (stand.geladen && stand.grussformeln.isEmpty)
              const Text(
                'Noch kein Gruß hinterlegt. Ohne Einträge bleibt die Auswahl '
                'beim Verfassen leer.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final gruss in stand.grussformeln)
                  InputChip(
                    label: Text(gruss.text),
                    onPressed: () => _bearbeite(context, gruss),
                    onDeleted: () => _entferne(context, gruss),
                    deleteButtonTooltipMessage: 'Gruß entfernen',
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Gruß hinzufügen'),
                  onPressed: () => _bearbeite(context, const Grussformel()),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
