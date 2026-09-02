import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagentext_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// **Vorlage und Ergebnis nebeneinander** (§4.7, geändert am 02.09.2026).
///
/// Vorher zeigte dieser Dialog nur den hinterlegten Vorlagentext mit einer
/// hervorgehobenen Zeile. Das war fast keine neue Auskunft: Dass
/// `{{Zusatzgruß}}` in Zeile 2 steht, weiß der Anwalt — er hat die Vorlage
/// geschrieben. Was er nicht sieht, ist die **Zuordnung**: Welche Vorlagenzeile
/// wurde welche Textzeile, und welche ist unterwegs verschwunden.
///
/// Genau das leistet die Gegenüberstellung. Links steht, was dasteht; rechts,
/// was daraus wurde — samt „entfällt" mit dem Namen des Platzhalters, der die
/// Zeile mitgenommen hat.
class VorlagentextDialog extends StatelessWidget {
  final MailVorlage vorlage;

  /// Was die Platzhalter ergeben haben — benennt den Grund an den entfallenen
  /// Zeilen. Leer heißt: nur den Wortlaut zeigen.
  final List<PlatzhalterBefund> befunde;

  const VorlagentextDialog({
    super.key,
    required this.vorlage,
    this.befunde = const [],
  });

  /// Öffnet den Dialog — der eine Weg hinein, damit die Aufrufer sich nicht um
  /// `showDialog` kümmern. Der Entwurfs-Cubit wird **mitgegeben**: Der Dialog
  /// hängt am Navigator-Overlay und findet ihn dort nicht mehr im Kontext.
  static Future<void> zeigen(
    BuildContext context, {
    required MailVorlage vorlage,
    List<PlatzhalterBefund> befunde = const [],
  }) {
    final cubit = context.read<EmailEntwurfCubit>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: VorlagentextDialog(vorlage: vorlage, befunde: befunde),
      ),
    );
  }

  /// Die leer gebliebenen Platzhalter, nach ihrer Zeile geordnet.
  Map<int, List<PlatzhalterBefund>> get _leerePro {
    final gruppen = <int, List<PlatzhalterBefund>>{};
    for (final befund in befunde.where((b) => b.istLeer)) {
      gruppen.putIfAbsent(befund.zeile, () => []).add(befund);
    }
    return gruppen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leere = _leerePro;
    final cubit = context.read<EmailEntwurfCubit>();
    // Ohne Füller (der Dialog dahinter lädt noch) bleibt die
    // Gegenüberstellung leer, statt mit einem Nullfehler aufzureissen — die
    // Übersicht, aus der dieser Dialog aufgeht, zeigt dann ohnehin nichts.
    final zeilen =
        cubit
            .fuellerFuer(cubit.state.entwurf.alleEmpfaenger)
            ?.gegenueberstellung(vorlage) ??
        const [];

    return AlertDialog(
      title: Text(vorlage.name),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              VorlagentextKopf(
                links: 'Vorlage, wie sie hinterlegt ist',
                rechts: 'Was daraus wurde',
              ),
              for (final zeile in zeilen)
                VorlagentextZeile(
                  nummer: zeile.nummer,
                  vorlage: zeile.nummer == 0 && zeile.vorlage.trim().isEmpty
                      ? 'Ohne Betreffzeile'
                      : zeile.vorlage,
                  ergebnis: zeile.ergebnis,
                  leere: leere[zeile.nummer] ?? const [],
                ),
              Text(
                'Die Vorlage selbst ändern Sie in den Einstellungen ▸ E-Mail.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}

/// Die Spaltenüberschriften der Gegenüberstellung. Ohne sie stünden zwei
/// Textblöcke nebeneinander, und welcher welcher ist, müsste man raten.
class VorlagentextKopf extends StatelessWidget {
  final String links;
  final String rechts;

  const VorlagentextKopf({
    super.key,
    required this.links,
    required this.rechts,
  });

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(child: Text(links, style: stil)),
          const SizedBox(width: 12),
          Expanded(child: Text(rechts, style: stil)),
        ],
      ),
    );
  }
}
