import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sagt seinem [builder], ob der gerade eingetippte Feldname als Platzhalter
/// in einer der beiden Word-Dateien vorkommt (#35 Teil 3) — null, solange
/// weder Name noch Platzhalterliste etwas hergeben.
///
/// Zwei Quellen laufen hier zusammen, und deshalb gibt es das Widget: das
/// Namens-Control (der Anwalt tippt) und der [TemplatePlaceholdersBloc] (er
/// verknüpft eine andere Datei). Beide Horcher an zwei Stellen nachzubauen —
/// im Kennzeichen und in der Bezeichnungszelle, die für das Kennzeichen Platz
/// freihalten muss — hiesse, dass die eine Stelle irgendwann etwas anderes
/// sieht als die andere.
class FeldVorkommenBeobachter extends StatelessWidget {
  /// Schlüssel des reactive_forms-Controls, in dem der Feldname steht.
  final String formControlName;

  final Widget Function(BuildContext context, FeldVorkommen? vorkommen) builder;

  const FeldVorkommenBeobachter({
    super.key,
    required this.formControlName,
    required this.builder,
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
          builder: (context, control, _) => builder(
            context,
            FeldVorkommen.bestimme(
              control.value,
              ohneAuflistung: ohne,
              mitAuflistung: mit,
            ),
          ),
        );
      },
    );
  }
}
