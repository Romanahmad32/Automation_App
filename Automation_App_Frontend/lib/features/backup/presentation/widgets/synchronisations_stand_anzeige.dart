import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

/// Zeitpunkte bezeichnen die lokale Ablage, niemals einen bestätigten Cloud-Upload.
class SynchronisationsStandAnzeige extends StatelessWidget {
  final UebergabeStand? stand;
  final DateTime? geprueft;

  const SynchronisationsStandAnzeige({super.key, this.stand, this.geprueft});

  @override
  Widget build(BuildContext context) {
    final status = stand;
    final basis = status?.eigenerStandGesichertAm;
    final angebot = status?.angebot;
    final lauf = status?.letzteSicherung;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          status == null
              ? 'Automatische Bereitstellung: Status wird geprüft.'
              : status.ablageOrdner.isEmpty
              ? 'Automatische Bereitstellung ist aus. Unter Kanzleidaten den gemeinsamen OneDrive-Ordner einrichten.'
              : 'Automatisch bei Änderungen: alle 30 Minuten, beim Vorgangsabschluss und beim Beenden. '
                    'Für einen sofortigen Arbeitsplatzwechsel „Jetzt bereitstellen“ wählen.',
        ),
        if (status != null) ...[
          Text(
            basis == null
                ? 'Lokaler Vergleichsstand: noch keine Bereitstellung oder Übernahme bekannt.'
                : 'Lokaler Vergleichsstand: Sicherung vom ${SicherungsZeitpunkt.beschreibe(basis)}.',
          ),
          if (status.lokaleAenderungen)
            const Text(
              'Seit diesem Vergleichsstand gibt es lokale Änderungen, die noch bereitgestellt werden müssen.',
            ),
          if (lauf != null)
            Text(
              '${lauf.gelungen ? 'Zuletzt im Ordner bereitgestellter Stand' : 'Letzter Sicherungsversuch fehlgeschlagen'}: '
              '${SicherungsZeitpunkt.beschreibe(lauf.zeitpunkt)}. ${lauf.meldung ?? ''}',
            ),
          if (lauf?.gelungen == true && lauf?.datei != null)
            SelectableText('Bereitgestellte Datei: ${lauf!.datei}'),
          if (angebot != null)
            SelectableText(
              'Zur Übernahme: ${angebot.rechnername} · Sicherung vom '
              '${SicherungsZeitpunkt.beschreibe(angebot.gesichertAm)}\nDatei: ${angebot.sicherung}',
            ),
          if (status.hinweis.isNotEmpty) Text(status.hinweis),
        ],
        const Text(
          'OneDrive-Upload: von der App nicht prüfbar. „Bereitgestellt“ bedeutet im gemeinsamen Ordner abgelegt. '
          'Am Zielrechner wird der Stand erst nach bestätigter Übernahme verwendet.',
        ),
        if (geprueft != null)
          Text(
            'Status zuletzt geprüft: ${SicherungsZeitpunkt.beschreibe(geprueft!)} · Prüfung alle 15 Sekunden.',
          ),
      ],
    );
  }
}
