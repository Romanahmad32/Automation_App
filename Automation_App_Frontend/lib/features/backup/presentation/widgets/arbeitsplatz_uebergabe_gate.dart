import 'dart:async';

import 'package:automation_app/core/backend/backend_start_screen.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/widgets/arbeitsplatz_uebergabe_screen.dart';
import 'package:flutter/material.dart';

/// Steht zwischen „Dienst bereit" und der Anwendung und fragt genau einmal
/// nach, wenn am anderen Arbeitsplatz ein neuerer Stand liegt (§7.2).
///
/// Gibt es nichts zu entscheiden — der Normalfall —, reicht er unverändert
/// durch; der Anwalt sieht nie, dass es ihn gibt.
///
/// **Was hier nicht passiert: blockieren.** Ist die Auskunft nicht zu bekommen
/// (Dienst zickt, Ordner offline), geht der Start weiter. Ein Arbeitsplatz, den
/// man nicht mehr öffnen kann, weil der andere unerreichbar ist, wäre die
/// schlechteste Antwort auf ein Problem, das im Zweifel gar keines ist.
class ArbeitsplatzUebergabeGate extends StatefulWidget {
  /// Baut die eigentliche Anwendung, sobald entschieden ist.
  final Widget Function() anwendungBauen;

  const ArbeitsplatzUebergabeGate({super.key, required this.anwendungBauen});

  @override
  State<ArbeitsplatzUebergabeGate> createState() =>
      ArbeitsplatzUebergabeGateState();
}

class ArbeitsplatzUebergabeGateState extends State<ArbeitsplatzUebergabeGate> {
  UebergabeStand? _stand;
  bool _weiter = false;
  bool _laeuft = false;
  String? _fehler;

  BackupRepository get _backup => getIt<BackupRepository>();

  @override
  void initState() {
    super.initState();
    unawaited(_laden());
  }

  Future<void> _laden() async {
    UebergabeStand stand;
    try {
      stand = await _backup.uebergabeStand();
    } catch (_) {
      stand = UebergabeStand.still;
    }
    if (!mounted) return;
    setState(() => _stand = stand);
  }

  /// Weiter in die Anwendung — mit dem eigenen Stand. Eine gelesene
  /// Fehlermeldung wird dabei quittiert, sonst stünde sie beim nächsten Start
  /// wieder da.
  Future<void> _weitergehen() async {
    if (_stand?.letzteSicherung?.offenerFehler ?? false) {
      try {
        await _backup.quittiereSicherungsfehler();
      } catch (_) {
        // Die Quittung ist Nebensache; der Start ist die Hauptsache.
      }
    }
    if (!mounted) return;
    setState(() => _weiter = true);
  }

  Future<void> _uebernehmen() async {
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      await _backup.uebernehmeStand();
    } catch (fehler) {
      if (!mounted) return;
      setState(() {
        _laeuft = false;
        // Der eigene Stand ist unberührt — das Backend spielt alles oder
        // nichts ein. Deshalb bleibt der Bildschirm stehen: Der Anwalt kann es
        // erneut versuchen oder seinen Stand behalten.
        _fehler =
            'Der Stand konnte nicht übernommen werden: $fehler '
            'Auf diesem Rechner hat sich nichts geändert.';
      });
      return;
    }

    await _weitergehen();
  }

  @override
  Widget build(BuildContext context) {
    final stand = _stand;
    if (stand == null) return const BackendStartScreen();
    if (_weiter || !stand.brauchtRueckfrage) return widget.anwendungBauen();

    return ArbeitsplatzUebergabeScreen(
      stand: stand,
      onUebernehmen: () => unawaited(_uebernehmen()),
      onWeiter: () => unawaited(_weitergehen()),
      laeuft: _laeuft,
      fehler: _fehler,
    );
  }
}
