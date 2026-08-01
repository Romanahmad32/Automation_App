import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_uebersicht_dialog.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Button am Ende der Mandanten-Karte: erst aktiv, wenn ein bestehender Mandant
/// geänderte Daten hat („Mandantendaten aktualisieren") oder ohne Auswahl das
/// Mindeste für einen neuen Mandanten erfasst ist („Neuen Mandanten speichern").
/// Öffnet vor dem Speichern die Übersicht zur Bestätigung (Req. 3) und meldet die
/// bestätigte Aktion über [onBestaetigt]; speichert nur den Mandanten, nicht den
/// Vorgang.
class MandantSpeichernButton extends StatelessWidget {
  final Rechtsgebiet rechtsgebiet;
  final Mandant? gewaehlterMandant;
  final void Function(MandantAenderungsart art, VorgangStartenDaten daten)
  onBestaetigt;

  const MandantSpeichernButton({
    super.key,
    required this.rechtsgebiet,
    required this.gewaehlterMandant,
    required this.onBestaetigt,
  });

  bool _mandantFelderGueltig(FormGroup form) =>
      form.control('mandantEmail').valid &&
      form.control('mandantKennzeichen').valid;

  Future<void> _bestaetige(
    BuildContext context,
    MandantAenderungsart art,
    VorgangStartenDaten daten,
  ) async {
    final istNeu = art == MandantAenderungsart.neu;
    final zeilen = istNeu
        ? mandantNeuFelder(daten)
        : mandantDiff(daten, gewaehlterMandant!);
    final bestaetigt = await MandantUebersichtDialog.zeige(
      context,
      istNeu: istNeu,
      zeilen: zeilen,
    );
    if (bestaetigt == true) onBestaetigt(art, daten);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangStartenBloc, VorgangStartenState>(
      builder: (context, state) {
        final isLoading = state is VorgangStartenLoading;
        return ReactiveFormConsumer(
          builder: (context, form, child) {
            final daten = leseVorgangDaten(form, rechtsgebiet);
            final art = mandantAenderungsart(daten, gewaehlterMandant);
            final aktiv = !isLoading &&
                art != MandantAenderungsart.keine &&
                _mandantFelderGueltig(form);
            final neu = art == MandantAenderungsart.neu;
            return Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: Icon(
                  neu ? Icons.person_add_alt_1_outlined : Icons.edit_note_outlined,
                ),
                label: Text(
                  neu
                      ? 'Neuen Mandanten speichern'
                      : 'Mandantendaten aktualisieren',
                ),
                onPressed:
                    aktiv ? () => _bestaetige(context, art, daten) : null,
              ),
            );
          },
        );
      },
    );
  }
}
