import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_stand_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Verdrahtet [VorlagenStandKarte] mit dem, woraus der Stand entsteht: den
/// gelesenen Platzhaltern je Slot aus dem [TemplatePlaceholdersBloc] und den
/// Feldnamen aus der `FormGroup`.
///
/// Getrennt von der Karte, damit die Karte reine Anzeige bleibt und ohne Bloc
/// und ohne Formular prüfbar ist. Die Trennung hat sich mit Stufe 3a bewährt:
/// Die Karte ist in die linke Spalte gewandert, dieses Stück Verdrahtung ist
/// unverändert mitgekommen.
///
/// Der [ReactiveFormConsumer] ist kein Beiwerk: Die Feldnamen leben in den
/// Controls, und wer im Namensfeld tippt, baut die Seite nicht neu auf. Ohne
/// ihn stünde der Stand auf dem Stand des letzten `setState` — dieselbe Falle
/// wie bei `TemplateFileSlots` und der Verlassen-Wache.
class VorlagenStandBereich extends StatelessWidget {
  final VorlagenBearbeitung bearbeitung;

  /// Weitergereicht an die Karte: „Alle übernehmen" legt zu jedem offenen
  /// Platzhalter ein Feld an.
  final void Function(List<String> platzhalter)? onAlleUebernehmen;

  const VorlagenStandBereich({
    super.key,
    required this.bearbeitung,
    this.onAlleUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, zustand) => ReactiveFormConsumer(
        builder: (context, formGroup, child) => VorlagenStandKarte(
          stand: bearbeitung.stand(zustand),
          onAlleUebernehmen: onAlleUebernehmen,
        ),
      ),
    );
  }
}
