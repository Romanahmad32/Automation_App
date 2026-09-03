import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Vorsteuer-Checkbox im Schadensaufstellungs-Schritt.
///
/// Sie ist ein synchronisiertes Spiegelbild der Checkbox aus dem Schritt
/// "Vorlage wählen & ausfüllen" — gemeinsame Quelle ist
/// [WizardState.vorsteuerabzugsberechtigt]. Weil dieselbe Einstellung dort auch
/// das Ankreuzen im Dokument steuert ("ist / ist nicht
/// vorsteuerabzugsberechtigt"), wird eine Änderung **hier** per Dialog
/// bestätigt, bevor sie übernommen wird: Wer in der Aufstellung an der
/// Umsatzsteuer dreht, ändert sonst nebenbei das Kreuz im Schreiben.
class VorsteuerCheckboxKarte extends StatelessWidget {
  const VorsteuerCheckboxKarte({super.key});

  Future<void> _bestaetigeUmschaltung(BuildContext context, bool wert) async {
    final cubit = context.read<WizardCubit>();
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Vorsteuerabzugsberechtigung ändern?',
      text:
          'Diese Einstellung stammt aus dem Schritt "Vorlage wählen & '
          'ausfüllen". Sie beeinflusst nicht nur die Umsatzsteuer in der '
          'Schadensaufstellung, sondern auch das Ankreuzen im Dokument '
          '("ist / ist nicht vorsteuerabzugsberechtigt"). Möchten Sie sie '
          'wirklich ändern?',
      bestaetigung: 'Ändern',
    );
    if (bestaetigt) {
      // Nur das gemeinsame Cubit-Feld setzen; die Neuberechnung von applyVat
      // und der RVG-Kosten erledigt der BlocListener des Schritts.
      cubit.setVorsteuerabzugsberechtigt(wert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vorsteuerabzugsberechtigt = context.select<WizardCubit, bool>(
      (cubit) => cubit.state.vorsteuerabzugsberechtigt,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: const Text('Mandant ist vorsteuerabzugsberechtigt'),
        subtitle: const Text(
          'Übernommen aus "Vorlage wählen & ausfüllen". '
          'Steuert die RVG-Umsatzsteuer dieser Aufstellung.',
        ),
        value: vorsteuerabzugsberechtigt,
        onChanged: (wert) => _bestaetigeUmschaltung(context, wert ?? false),
      ),
    );
  }
}
