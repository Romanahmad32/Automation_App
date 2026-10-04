import 'package:automation_app/core/general_widgets/pdf_dokument_ansicht.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die ausgefüllte Seite neben den Feldern (§4.11, #164) — damit ein
/// Tippfehler oder eine leere Zeile vor dem Papier auffällt, nicht danach.
///
/// Neu erzeugt wird sie nur auf „Aktualisieren" (und einmal, sobald sie
/// fällig ist — das stößt der Dialog an): Eine Umwandlung belegt den
/// Word-Thread, in dessen Schlange auch der Druck wartet. Passt sie nicht
/// mehr zu den Feldern, sagt das ein Hinweis — gedruckt werden immer die
/// aktuellen Felder.
///
/// Braucht eine begrenzte Höhe; die gibt `VollmachtArbeitsflaeche` vor. Der
/// Knopf heißt kurz „Aktualisieren": Bei „Am größten" war „Vorschau
/// aktualisieren" allein breiter als die Spalte.
class VollmachtVorschauFlaeche extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtVorschauFlaeche({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<VollmachtCubit>();
    final aktualisierbar =
        stand.phase == VollmachtPhase.eingabe &&
        stand.art != null &&
        !stand.vorlageFehlt &&
        !stand.vorschauLaedt;
    final warnungen = stand.vorschau?.warnungen ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Vorschau', style: theme.textTheme.titleSmall),
            ),
            Tooltip(
              message: 'Vorschau aktualisieren',
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
                onPressed: aktualisierbar ? cubit.erstelleVorschau : null,
              ),
            ),
          ],
        ),
        if (stand.vorschauVeraltet && !stand.vorschauLaedt)
          const VollmachtHinweis(
            icon: Icons.update,
            text:
                'Die Vorschau zeigt nicht den aktuellen Stand — gedruckt '
                'werden die aktuellen Felder.',
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _seite(theme),
          ),
        ),
        if (warnungen.isNotEmpty)
          VollmachtHinweis(
            icon: Icons.warning_amber_outlined,
            text:
                'Nicht ersetzt: ${warnungen.map((w) => '{{$w}}').join(', ')}.',
          ),
      ],
    );
  }

  Widget _seite(ThemeData theme) {
    final vorschau = stand.vorschau;
    final pdf = vorschau?.pdf;
    if (vorschau != null &&
        vorschau.status == VollmachtVorschauStatus.erstellt &&
        pdf != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PdfDokumentAnsicht(
            pdf: pdf,
            quelle: 'vollmacht-vorschau-${stand.vorschauNummer}.pdf',
          ),
          if (stand.vorschauLaedt)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
        ],
      );
    }

    final (icon, text) = switch (vorschau) {
      _ when stand.vorschauLaedt => (null, 'Vorschau wird erstellt …'),
      null => (
        Icons.description_outlined,
        'Die Vorschau erscheint, sobald Art und Vorlage feststehen.',
      ),
      VollmachtVorschau(:final meldung) => (
        Icons.visibility_off_outlined,
        meldung ?? 'Die Vorschau ließ sich nicht erzeugen.',
      ),
    };
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              if (icon == null)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
