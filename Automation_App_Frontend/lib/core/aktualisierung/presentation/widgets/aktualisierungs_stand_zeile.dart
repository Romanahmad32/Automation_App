import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/general_widgets/hinweis_zeile.dart';
import 'package:material_ui/material_ui.dart';

/// Ein Satz dazu, ob es eine neuere Version gibt — in „Über diese Anwendung“
/// und im Dialog, wenn dort gerade kein Update in Sicht ist.
///
/// „Keine neuere Version“ und „konnte nicht nachsehen“ sind bewusst zwei
/// verschiedene Antworten. Beides als „Sie sind aktuell“ zu zeigen, wäre eine
/// Falschaussage — der Anwalt würde sich auf eine Prüfung verlassen, die nie
/// stattgefunden hat.
class AktualisierungsStandZeile extends StatelessWidget {
  const AktualisierungsStandZeile({required this.ansicht, super.key});

  /// `null`, solange niemand gefragt hat (Widget-Tests ohne Dienst).
  final AktualisierungsAnsicht? ansicht;

  static const String wirdNachgesehen =
      'Es wird nachgesehen, ob eine neuere Version vorliegt …';

  static const String nichtNachgesehen =
      'Es konnte nicht nachgesehen werden, ob eine neuere Version vorliegt. '
      'Meist fehlt dafür nur die Internetverbindung.';

  static const String neueste = 'Sie verwenden die neueste Version.';

  @override
  Widget build(BuildContext context) {
    final primaer = Theme.of(context).colorScheme.primary;
    final aktuell = ansicht;
    final stand = aktuell?.stand;
    if (aktuell != null && aktuell.updateInSicht) {
      return HinweisZeile(
        symbol: Icons.new_releases,
        text: 'Version ${stand!.neueVersion} ist verfügbar.',
        farbe: primaer,
      );
    }
    if (stand?.zustand == AktualisierungsZustand.aktuell) {
      return HinweisZeile(
        symbol: Icons.check_circle,
        text: neueste,
        farbe: primaer,
      );
    }
    // Der Dienst antwortete nicht, oder seine Prüfung ging nicht (dann steht
    // eine Meldung im Stand). Sonst ist die Antwort noch unterwegs. Die
    // Meldung des Dienstes nennt die Ursache (keine Verbindung, Server
    // ausgelastet, #199) — der feste Satz gilt nur, wenn keine da ist.
    // Schweigt der Dienst, ist eine ältere Meldung überholt.
    final stumm = aktuell?.dienstStumm ?? false;
    final meldung = stumm ? null : stand?.meldung;
    final gescheitert = stumm || meldung != null;
    return gescheitert
        ? HinweisZeile(
            symbol: Icons.cloud_off,
            text: meldung ?? nichtNachgesehen,
          )
        : const HinweisZeile(
            symbol: Icons.hourglass_empty,
            text: wirdNachgesehen,
          );
  }
}
