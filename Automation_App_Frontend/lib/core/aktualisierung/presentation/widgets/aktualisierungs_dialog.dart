import 'dart:async';

import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_dialog_phase.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog_inhalt.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/selbst_herunterladen_knopf.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Der Dialog „App aktualisieren“ (#196): verfügbar → lädt → bereit →
/// „Jetzt neu starten“, dazu Fehler und die letzten Sekunden vor dem
/// Schließen. Geöffnet über den Hinweis in der Seitenleiste, über
/// „Aktualisieren …“ in „Über diese Anwendung“ und über „Erneut versuchen“
/// in der Rückmeldung nach einem gescheiterten Update.
///
/// Er lässt sich jederzeit schließen — das Laden läuft im Dienst weiter, die
/// Seitenleiste zeigt den Stand. Nur in den letzten Sekunden (2e) nicht mehr:
/// Dann läuft der Installer schon, und ein zweiter Klick soll nichts mehr
/// auslösen können.
class AktualisierungsDialog extends StatelessWidget {
  static const Key spaeterSchluessel = ValueKey('aktualisierung-spaeter');
  static const Key schliessenSchluessel = ValueKey('aktualisierung-schliessen');
  static const Key ladenAbbrechenSchluessel = ValueKey(
    'aktualisierung-laden-abbrechen',
  );

  /// „Jetzt neu starten“ — startet im echten Betrieb den Installer und
  /// schließt die App.
  static const Key neuStartenSchluessel = ValueKey(
    'aktualisierung-neu-starten',
  );
  static const Key erneutVersuchenSchluessel = ValueKey(
    'aktualisierung-erneut-versuchen',
  );

  const AktualisierungsDialog({required this.cubit, super.key});

  final AktualisierungCubit cubit;

  /// Öffnet den Dialog im Zustand, in dem die Aktualisierung gerade steht.
  /// Mit [erneutVersuchen] lädt er gleich neu (3c „Erneut versuchen“).
  /// [cubit] gibt ein Test vor; sonst der app-weite aus `getIt`.
  static Future<void> zeigen(
    BuildContext context, {
    bool erneutVersuchen = false,
    AktualisierungCubit? cubit,
  }) {
    final traeger = cubit ?? getIt<AktualisierungCubit>();
    unawaited(
      erneutVersuchen ? traeger.erneutVersuchen() : traeger.auffrischen(),
    );
    return showDialog<void>(
      context: context,
      builder: (_) => AktualisierungsDialog(cubit: traeger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AktualisierungCubit, AktualisierungsAnsicht>(
      bloc: cubit,
      listenWhen: (alt, neu) => neu.testmodusNeustart,
      listener: _testmodusNeustart,
      builder: (context, ansicht) {
        final phase = ansicht.dialogPhase;
        final adresse = ansicht.stand?.downloadUrl;
        final geteilt =
            phase == AktualisierungsDialogPhase.verfuegbar && adresse != null;
        final knoepfe = _knoepfe(context, ansicht, phase);
        return PopScope(
          canPop: phase != AktualisierungsDialogPhase.schliesst,
          child: AlertDialog(
            title: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.system_update,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Expanded(
                  child: Text(
                    'App aktualisieren',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: AktualisierungsDialogInhalt(
                  ansicht: ansicht,
                  cubit: cubit,
                ),
              ),
            ),
            actionsAlignment: geteilt
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            actions: knoepfe.isEmpty ? null : knoepfe,
          ),
        );
      },
    );
  }

  /// Je Zustand die Knöpfe der Vorschau. Der Normalfall ist der gefüllte.
  List<Widget> _knoepfe(
    BuildContext context,
    AktualisierungsAnsicht ansicht,
    AktualisierungsDialogPhase phase,
  ) {
    void schliessen() => Navigator.of(context).pop();
    final frei = !ansicht.arbeitet;
    final adresse = ansicht.stand?.downloadUrl;
    return switch (phase) {
      AktualisierungsDialogPhase.verfuegbar => [
        if (adresse != null) SelbstHerunterladenKnopf(adresse: adresse),
        TextButton(
          key: spaeterSchluessel,
          onPressed: schliessen,
          child: const Text('Später'),
        ),
      ],
      AktualisierungsDialogPhase.laedt => [
        TextButton(
          key: ladenAbbrechenSchluessel,
          onPressed: frei ? cubit.abbrechen : null,
          child: const Text('Laden abbrechen'),
        ),
        FilledButton(
          key: schliessenSchluessel,
          onPressed: schliessen,
          child: const Text('Schließen'),
        ),
      ],
      AktualisierungsDialogPhase.bereit => [
        TextButton(
          key: spaeterSchluessel,
          onPressed: schliessen,
          child: const Text('Später'),
        ),
        FilledButton.icon(
          key: neuStartenSchluessel,
          onPressed: frei ? cubit.installieren : null,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Jetzt neu starten'),
        ),
      ],
      AktualisierungsDialogPhase.fehler => [
        TextButton(
          key: schliessenSchluessel,
          onPressed: schliessen,
          child: const Text('Schließen'),
        ),
        FilledButton.icon(
          key: erneutVersuchenSchluessel,
          onPressed: frei ? cubit.erneutVersuchen : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Erneut versuchen'),
        ),
      ],
      AktualisierungsDialogPhase.schliesst => const [],
      AktualisierungsDialogPhase.ohneUpdate => [
        TextButton(
          key: schliessenSchluessel,
          onPressed: schliessen,
          child: const Text('Schließen'),
        ),
      ],
    };
  }

  /// Im Testmodus geht die App nach „Jetzt neu starten“ nicht zu (sonst
  /// endete die E2E-Suite mittendrin): Der Dialog schließt, eine Rückmeldung
  /// sagt, was stattdessen geschah.
  static void _testmodusNeustart(
    BuildContext context,
    AktualisierungsAnsicht _,
  ) {
    Rueckmeldung.von(context).hinweis(AktualisierungCubit.testmodusHinweis);
    Navigator.of(context).pop();
  }
}
