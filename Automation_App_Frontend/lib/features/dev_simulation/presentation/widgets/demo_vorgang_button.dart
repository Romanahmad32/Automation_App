import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Demo-Kennzeichen, aus denen der Demo-Vorgang reihum wählt (Konvention
/// „Unterscheidungszeichen-Erkennungsbuchstaben Nummer").
const List<String> demoKennzeichen = [
  'GG-XY 123',
  'F-AB 1234',
  'HG-E 1427',
  'OF-XY 77',
];

/// Entwickler-Knopf (nur im Debug-Build sichtbar): legt einen Demo-Vorgang mit
/// plausiblen Daten im Status „Angefragt" an — der Startpunkt, um den gesamten
/// Lebenszyklus in der App durchzuspielen, ohne das Zentralruf-Formular
/// auszufüllen. Die weiteren Schritte simuliert das SimulationMenu am Vorgang.
class DemoVorgangButton extends StatelessWidget {
  const DemoVorgangButton({super.key});

  Future<void> _anlegen(BuildContext context) async {
    final cubit = getIt<VorgangCubit>();

    // Nächste freie laufende Nummer aus dem Bestand, damit der Demo-Vorgang
    // keine echte Referenz überschreibt.
    var nummer = 1;
    for (final vorhanden in cubit.state) {
      final vorhandeneNummer = vorhanden.laufendeNummer;
      if (vorhandeneNummer != null && vorhandeneNummer >= nummer) {
        nummer = vorhandeneNummer + 1;
      }
    }

    final jetzt = DateTime.now();
    final jahr = (jetzt.year % 100).toString().padLeft(2, '0');
    final kennzeichen =
        demoKennzeichen[cubit.state.length % demoKennzeichen.length];
    final referenz = '$nummer/$jahr C03_$kennzeichen';

    final unfall = jetzt.subtract(const Duration(days: 14));

    await cubit.registriereAnfrage(
      referenz,
      mandantName: 'Mustermann, Max (Demo)',
      unfallDatum: deutschesDatum(unfall),
      geschaedigtenKennzeichen: 'HG-E 1427',
      unfallort: 'Frankfurt am Main',
      unfalluhrzeit: '14:30',
    );

    if (!context.mounted) return;
    final zeichen = ReferenzTeile.zeichenAus(referenz);
    Rueckmeldung.zeigeErfolg(
      context,
      'Demo-Vorgang „$zeichen" angelegt (Status: Angefragt). Nächste '
      'Schritte über das Simulations-Menü des Vorgangs.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.science_outlined),
      label: const Text('Demo-Vorgang'),
      onPressed: () => _anlegen(context),
    );
  }
}
