import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/auftrag_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/referenz_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/unfall_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/unfallhergang_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/weiter_aktionen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Scrollbarer Inhalt des „Vorgang starten"-Formulars: die Abschnitte (Auftrag,
/// Unfall, Referenz, Mandant, Unfallhergang) und nach dem Speichern die
/// Weiter-Aktionen. Hält selbst keinen State; alle Werte/Callbacks kommen aus der
/// View. Unfall-/Unfallhergang-Teile erscheinen nur bei Verkehrsrecht.
class VorgangStartenSektionen extends StatelessWidget {
  final Rechtsgebiet rechtsgebiet;
  final bool istVerkehrsunfall;
  final ValueChanged<Rechtsgebiet> onRechtsgebietChanged;
  final bool referenzManuallyEdited;
  final VoidCallback onReferenzReset;
  final List<Mandant> mandanten;
  final int? selectedMandantId;
  final ValueChanged<Mandant> onMandantGewaehlt;
  final VoidCallback onAuswahlAufheben;
  final ValueChanged<String> onKennzeichenGewaehlt;
  final void Function(MandantAenderungsart art, VorgangStartenDaten daten)
  onMandantBestaetigt;
  final ValueChanged<String> onVorlageAusfuellen;
  final VoidCallback onZumPostfach;

  const VorgangStartenSektionen({
    super.key,
    required this.rechtsgebiet,
    required this.istVerkehrsunfall,
    required this.onRechtsgebietChanged,
    required this.referenzManuallyEdited,
    required this.onReferenzReset,
    required this.mandanten,
    required this.selectedMandantId,
    required this.onMandantGewaehlt,
    required this.onAuswahlAufheben,
    required this.onKennzeichenGewaehlt,
    required this.onMandantBestaetigt,
    required this.onVorlageAusfuellen,
    required this.onZumPostfach,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              AuftragSection(
                rechtsgebiet: rechtsgebiet,
                onRechtsgebietChanged: onRechtsgebietChanged,
              ),
              if (istVerkehrsunfall) const UnfallSection(),
              ReferenzSection(
                referenzManuallyEdited: referenzManuallyEdited,
                onReset: onReferenzReset,
              ),
              MandantSection(
                mandanten: mandanten,
                selectedMandantId: selectedMandantId,
                rechtsgebiet: rechtsgebiet,
                onMandantGewaehlt: onMandantGewaehlt,
                onAuswahlAufheben: onAuswahlAufheben,
                onKennzeichenGewaehlt: onKennzeichenGewaehlt,
                onMandantBestaetigt: onMandantBestaetigt,
              ),
              if (istVerkehrsunfall) const UnfallhergangSection(),
              BlocBuilder<VorgangStartenBloc, VorgangStartenState>(
                builder: (context, state) => state is VorgangGespeichert
                    ? WeiterAktionen(
                        referenz: state.referenz,
                        onVorlageAusfuellen: () =>
                            onVorlageAusfuellen(state.referenz),
                        onZumPostfach: onZumPostfach,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
