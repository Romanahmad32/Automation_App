import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Kennzeichen an einer Feldzeile: In welcher Word-Datei kommt der (gerade
/// eingetragene) Feldname als Platzhalter vor — *beide · nur HGN · nur
/// Auflistung · in keiner Datei* (#35 Teil 3)?
///
/// Hört auf das Namens-Control ([formControlName]) und auf den
/// [TemplatePlaceholdersBloc], wandert also beim Tippen und beim Verknüpfen
/// einer anderen Datei mit. Ohne bekannte Platzhalter oder ohne Namen zeigt
/// es nichts.
///
/// Sagt es „in keiner Datei", ist es zugleich der Weg zur Reparatur: Ein Klick
/// öffnet die Zuordnung (#36), statt den Anwalt mit dem Befund allein zu
/// lassen. Die anderen drei Fälle sind reine Auskunft und nicht klickbar.
class FeldVorkommenBadge extends StatelessWidget {
  final String formControlName;

  /// Wird beim Klick auf ein „in keiner Datei" gerufen. Null lässt das
  /// Kennzeichen stumm — etwa dort, wo es keine Platzhalterliste zum Wählen
  /// gibt.
  final VoidCallback? onZuordnen;

  const FeldVorkommenBadge({
    super.key,
    required this.formControlName,
    this.onZuordnen,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, state) {
        Set<String>? platzhalterVon(TemplateFileSlot slot) =>
            switch (state.forSlot(slot)) {
              SlotPlaceholdersLoaded(placeholders: final p) => p.toSet(),
              _ => null,
            };
        final ohne = platzhalterVon(TemplateFileSlot.ohneAuflistung);
        final mit = platzhalterVon(TemplateFileSlot.mitAuflistung);

        return ReactiveValueListenableBuilder<String>(
          formControlName: formControlName,
          builder: (context, control, child) {
            final vorkommen = FeldVorkommen.bestimme(
              control.value,
              ohneAuflistung: ohne,
              mitAuflistung: mit,
            );
            if (vorkommen == null) return const SizedBox.shrink();

            final theme = Theme.of(context);
            final warnung = vorkommen == FeldVorkommen.inKeinerDatei;
            final farbe = warnung
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant;
            final zuordnen = warnung ? onZuordnen : null;
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Tooltip(
                message: zuordnen == null
                    ? vorkommen.erklaerung
                    : '${vorkommen.erklaerung} '
                          'Anklicken, um einen Platzhalter zuzuordnen.',
                child: InkWell(
                  onTap: zuordnen,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: farbe),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(
                          vorkommen.anzeige,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: farbe,
                          ),
                        ),
                        if (zuordnen != null)
                          Icon(Icons.link, size: 12, color: farbe),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
