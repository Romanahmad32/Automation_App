import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

class SynchronisationsDetails extends StatelessWidget {
  final UebergabeStand? stand;
  final DateTime? geprueft;
  const SynchronisationsDetails({super.key, this.stand, this.geprueft});

  static Future<void> zeigen(
    BuildContext context,
    UebergabeStand? stand,
    DateTime? geprueft,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zwischen Büro und Zuhause wechseln'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SynchronisationsDetails(stand: stand, geprueft: geprueft),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Verstanden'),
        ),
      ],
    ),
  );
  static String titel(UebergabeStand stand) {
    if (stand.letzteSicherung?.offenerFehler ?? false) {
      return 'Arbeitsplatzwechsel: Letzte Sicherung fehlgeschlagen';
    }
    return 'Arbeitsplatzwechsel: ${switch (stand.zustand) {
      'nichtEingerichtet' => 'Noch nicht eingerichtet',
      'nichtErreichbar' => 'Ordner oder Status nicht erreichbar',
      'konflikt' => 'Unterschiedliche Änderungen – bitte prüfen',
      'angebot' => 'Stand von ${stand.angebot?.rechnername ?? 'anderem Rechner'} verfügbar',
      'bereitstellen' => 'Sicherung wird gerade bereitgestellt …',
      'uebernehmen' => 'Datei wird geprüft und übernommen …',
      'warten' => 'Warte auf die Übertragung durch OneDrive',
      'geaendert' => 'Lokal gespeichert – Bereitstellung steht aus',
      _ => 'Bereitgestellt – OneDrive-Upload nicht bestätigt',
    }}';
  }

  @override
  Widget build(BuildContext context) {
    final lauf = stand?.letzteSicherung;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stand != null) Text(stand!.hinweis),
        if (geprueft != null)
          Text(
            'Zuletzt geprüft: ${SicherungsZeitpunkt.beschreibe(geprueft!)}.',
          ),
        if (lauf != null)
          Text(
            '${lauf.gelungen ? 'Im Ordner bereitgestellt' : 'Sicherung fehlgeschlagen'}: '
            '${SicherungsZeitpunkt.beschreibe(lauf.zeitpunkt)}. ${lauf.meldung ?? ''}',
          ),
        const SizedBox(height: 16),
        const Text(
          '1. Auf diesem Rechner Eingaben speichern und „Jetzt bereitstellen“ wählen.',
        ),
        const SizedBox(height: 8),
        const Text(
          '2. OneDrive überträgt die Datei im Hintergrund. Vor dem Ausschalten in OneDrive warten, bis die Synchronisierung abgeschlossen ist.',
        ),
        const SizedBox(height: 8),
        const Text(
          '3. Am anderen Rechner OneDrive synchronisieren lassen. Die App prüft alle 15 Sekunden. Unter Einstellungen → Datensicherung wird der angekommene Stand zur Übernahme angeboten.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Die App sichert Änderungen außerdem alle 30 Minuten, beim Vorgangsabschluss und beim Beenden. '
          '„Bereitgestellt“ bestätigt die lokale Ablage. Einen abgeschlossenen OneDrive-Upload kann die App nicht bestätigen; '
          'eine Übernahme am anderen Rechner wird dagegen sichtbar quittiert.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Einmalig auf beiden Rechnern unter „Gemeinsamer OneDrive-Ordner“ denselben Ordner wählen und in OneDrive „Immer auf diesem Gerät behalten“ wählen. '
          'Den Aktenstammordner ebenfalls synchronisieren. Postfach und Anmeldung werden je Rechner eingerichtet. '
          'Bitte abwechselnd arbeiten: Unterschiedliche Änderungen werden nicht automatisch zusammengeführt.',
        ),
        if (stand?.ablageOrdner.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          SelectableText('Gemeinsame Sicherungsablage: ${stand!.ablageOrdner}'),
        ],
      ],
    );
  }
}
