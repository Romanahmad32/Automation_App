import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:automation_app/features/backup/presentation/widgets/uebergabe_uebernahme_dialog.dart';
import 'package:flutter/material.dart';

/// Zeigt im Reiter „Datensicherung", wie es um die automatische Sicherung steht
/// (§7.2) — und bietet die Übernahme auch außerhalb des Starts an.
///
/// Diese Zeile ist die einzige Stelle, an der ein stiller Fehlschlag im Alltag
/// auffällt: Gesichert wird beim Beenden, wenn niemand mehr zusieht. Wer hier
/// „zuletzt gesichert heute um 18:04" liest, weiß, dass der Weg zum zweiten
/// Rechner offen ist — und wer stattdessen „noch nie" liest, weiß es auch.
class SicherungsStandZeile extends StatefulWidget {
  const SicherungsStandZeile({super.key});

  @override
  State<SicherungsStandZeile> createState() => SicherungsStandZeileState();

  static String satz(UebergabeStand stand) {
    if (stand.ablageOrdner.isEmpty) {
      return 'Nicht eingerichtet. In den Kanzleidaten unter „Sicherungsablage" '
          'einen Ordner wählen — dann sichert die App beim Beenden von selbst '
          'dorthin.';
    }

    final lauf = stand.letzteSicherung;
    if (lauf == null) {
      return 'Eingerichtet (${stand.ablageOrdner}), aber noch nie gelaufen. '
          'Die erste Sicherung entsteht beim Beenden der App.';
    }
    if (!lauf.gelungen) {
      return 'Zuletzt fehlgeschlagen '
          '${SicherungsZeitpunkt.beschreibe(lauf.zeitpunkt)}: '
          '${lauf.meldung ?? 'Grund unbekannt.'}';
    }
    final basis =
        'Zuletzt gesichert ${SicherungsZeitpunkt.beschreibe(lauf.zeitpunkt)} '
        'nach ${stand.ablageOrdner}.';
    final archivSatz = _archivSatz(stand);
    return archivSatz.isEmpty ? basis : '$basis $archivSatz';
  }

  /// Wie viele Archive dieses Rechners liegen und wie weit die Historie
  /// zurückreicht — leer, solange keins existiert, damit „gelungen" ohne
  /// Bestand nicht nach einer nie gelaufenen Aufräumung klingt.
  static String _archivSatz(UebergabeStand stand) {
    final anzahl = stand.eigeneArchive;
    if (anzahl <= 0) return '';
    if (anzahl == 1) return '1 Sicherung dieses Rechners.';
    final aeltestes = stand.aeltestesArchiv;
    if (aeltestes == null) return '$anzahl Sicherungen dieses Rechners.';
    return '$anzahl Sicherungen dieses Rechners, älteste vom '
        '${SicherungsZeitpunkt.datum(aeltestes)}.';
  }
}

class SicherungsStandZeileState extends State<SicherungsStandZeile> {
  UebergabeStand? _stand;

  @override
  void initState() {
    super.initState();
    unawaited(_laden());
  }

  Future<void> _laden() async {
    UebergabeStand? stand;
    try {
      stand = await getIt<BackupRepository>().uebergabeStand();
    } catch (_) {
      stand = UebergabeStand.still;
    }
    if (!mounted) return;
    setState(() => _stand = stand);
  }

  @override
  Widget build(BuildContext context) {
    final stand = _stand;
    if (stand == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text('Automatische Sicherung', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          SicherungsStandZeile.satz(stand),
          style: theme.textTheme.bodySmall,
        ),
        if (stand.angebot != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => unawaited(_uebernehmen()),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text('Stand von ${stand.angebot!.rechnername} übernehmen …'),
          ),
        ],
      ],
    );
  }

  Future<void> _uebernehmen() async {
    final angebot = _stand?.angebot;
    if (angebot == null) return;
    final melder = Rueckmeldung.von(context);

    final meldung = await UebergabeUebernahmeDialog.frageUndUebernimm(
      context,
      angebot,
    );
    if (meldung == null) return;

    melder.hinweis(meldung);
    await _laden();
  }
}
