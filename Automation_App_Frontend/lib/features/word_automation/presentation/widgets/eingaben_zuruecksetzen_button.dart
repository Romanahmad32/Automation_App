import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Weg zurück zur Vorbelegung (#133).
///
/// Der angefangene Stand kommt beim Wiedereinstieg **ohne Nachfrage** ins
/// Formular — das ist die freundliche Voreinstellung, aber sie braucht eine
/// Gegenrichtung: Wer seine Eingaben nicht mehr will, bekäme sie sonst bei jeder
/// Rückkehr wieder vorgesetzt und müsste jedes Feld einzeln auf den Wert aus dem
/// Bestand zurückstellen — den er dazu erst einmal kennen müsste.
///
/// Steht nur da, wenn es etwas zurückzusetzen gibt ([sichtbar]): Ein Knopf, der
/// nichts tut, sieht aus wie einer, der nicht funktioniert.
///
/// Dezent und rechtsbündig — er gehört zum Formular darunter, nicht in dessen
/// Blickachse. Schriftgrad und Farbe kommen vom [TextButton] und damit aus dem
/// Theme; die Schriftstufe stellt der Anwalt in den Einstellungen ein.
class EingabenZuruecksetzenButton extends StatelessWidget {
  /// Ob überhaupt etwas von der Vorbelegung abweicht. Rechnet der Aufrufer aus:
  /// Nur dort liegen Vorbelegung und gewählte Vorlage beisammen.
  final bool sichtbar;

  const EingabenZuruecksetzenButton({super.key, required this.sichtbar});

  /// Der Wortlaut, an einer Stelle — Knopf und Test lesen denselben.
  static const beschriftung = 'Eingaben auf Vorbelegung zurücksetzen';

  /// Was danach oben rechts steht.
  static const meldung = 'Eingaben zurückgesetzt.';

  /// Die Rücknahme daneben.
  static const rueckgaengig = 'Rückgängig';

  @override
  Widget build(BuildContext context) {
    if (!sichtbar) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.settings_backup_restore, size: 18),
        label: const Text(beschriftung),
        onPressed: () => _zuruecksetzen(context),
      ),
    );
  }

  /// Zurücksetzen heißt hier: löschen — im Formular **und** am Vorgang. Deshalb
  /// steht die Rücknahme daneben, und deshalb hält sie den Stand hier fest statt
  /// im Cubit: Ein gelöschter Stand, den der Cubit weiter hielte, wäre genau die
  /// stille Halbwahrheit, die #133 beseitigt.
  void _zuruecksetzen(BuildContext context) {
    final cubit = context.read<WizardCubit>();
    final rueckmeldung = Rueckmeldung.von(context);

    final bisher = cubit.setzeEingabenZurueck();
    rueckmeldung.hinweis(
      meldung,
      aktion: bisher == null
          ? null
          : RueckmeldungsAktion(
              text: rueckgaengig,
              // Die Meldung überlebt den Wizard: Wer die Seite verlässt,
              // während sie noch steht, drückte sonst auf einen geschlossenen
              // Cubit.
              beiDruck: () =>
                  cubit.isClosed ? null : cubit.stelleEingabenWiederHer(bisher),
            ),
    );
  }
}
