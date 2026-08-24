import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_format_auswahl.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/akte_auswahl.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/mandant_auswahl.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/unterordner_auswahl.dart';
import 'package:flutter/material.dart';

/// Eingabeformular der Akten-Ablage: Mandant, Akte und Unterordner (Fall)
/// wählen/anlegen und das Dokument ablegen. Hält selbst keinen Zustand; die
/// [AktenAblageSection] reicht Werte und Callbacks herein.
class AktenAblageFormular extends StatelessWidget {
  final Mandant? mandant;
  final List<Mandant> mandanten;
  final bool neueAkte;
  final String? gewaehlteAkte;
  final bool neuerFall;
  final String? gewaehlterFall;
  final List<String> faelle;
  final TextEditingController neueAkteController;
  final TextEditingController stichwortController;
  final TextEditingController datumController;
  final TextEditingController kennzeichenController;
  final String vorschau;

  /// Welche Fassungen in die Akte gehen (Word, PDF oder beide).
  final AblageFormat format;

  final bool isFiling;
  final ValueChanged<Mandant> onWaehleMandant;
  final VoidCallback onNeuerMandant;
  final VoidCallback onAendernMandant;
  final ValueChanged<String?> onAkteDropdownChanged;
  final VoidCallback onNeueAkteTextChanged;
  final ValueChanged<String?> onFallDropdownChanged;
  final VoidCallback onUnterordnerTextChanged;
  final ValueChanged<AblageFormat> onFormatChanged;
  final VoidCallback onAblegen;

  const AktenAblageFormular({
    super.key,
    required this.mandant,
    required this.mandanten,
    required this.neueAkte,
    required this.gewaehlteAkte,
    required this.neuerFall,
    required this.gewaehlterFall,
    required this.faelle,
    required this.neueAkteController,
    required this.stichwortController,
    required this.datumController,
    required this.kennzeichenController,
    required this.vorschau,
    required this.format,
    required this.isFiling,
    required this.onWaehleMandant,
    required this.onNeuerMandant,
    required this.onAendernMandant,
    required this.onAkteDropdownChanged,
    required this.onNeueAkteTextChanged,
    required this.onFallDropdownChanged,
    required this.onUnterordnerTextChanged,
    required this.onFormatChanged,
    required this.onAblegen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.folder_special, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'In Akte ablegen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Das Dokument wird unter dem Stammordner in der Akte des Mandanten '
          'gespeichert. Existiert die Akte noch nicht, wird sie angelegt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        MandantAuswahl(
          mandant: mandant,
          mandanten: mandanten,
          onWaehleMandant: onWaehleMandant,
          onNeuerMandant: onNeuerMandant,
          onAendern: onAendernMandant,
        ),
        if (mandant != null) ...[
          const SizedBox(height: 16),
          AkteAuswahl(
            mandant: mandant!,
            neueAkte: neueAkte,
            gewaehlteAkte: gewaehlteAkte,
            neueAkteController: neueAkteController,
            onDropdownChanged: onAkteDropdownChanged,
            onNeueAkteTextChanged: onNeueAkteTextChanged,
          ),
          const SizedBox(height: 16),
          UnterordnerAuswahl(
            neuerFall: neuerFall,
            gewaehlterFall: gewaehlterFall,
            faelle: faelle,
            stichwortController: stichwortController,
            datumController: datumController,
            kennzeichenController: kennzeichenController,
            vorschau: vorschau,
            onDropdownChanged: onFallDropdownChanged,
            onTextChanged: onUnterordnerTextChanged,
          ),
          const SizedBox(height: 16),
          AblageFormatAuswahl(format: format, onChanged: onFormatChanged),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isFiling ? null : onAblegen,
            icon: isFiling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_folder_upload),
            label: const Text('In Akte ablegen'),
          ),
        ],
      ],
    );
  }
}
