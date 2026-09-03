import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/presentation/widgets/sicherungs_fehler_karte.dart';
import 'package:automation_app/features/backup/presentation/widgets/uebergabe_angebot_karte.dart';
import 'package:flutter/material.dart';

/// Der Bildschirm, der beim Start vor der Oberfläche steht, wenn es etwas zu
/// entscheiden oder zu melden gibt (§7.2).
///
/// Bringt wie der `BackendStartScreen` seine eigene [MaterialApp] mit: Zu
/// diesem Zeitpunkt gibt es weder Router noch Theme der Anwendung. Und genau
/// deshalb steht er hier — die Frage kommt, **bevor** irgendeine Ansicht Daten
/// geladen hat. Eine Übernahme mitten im Betrieb hiesse, dass halb gefüllte
/// Formulare auf einen ausgetauschten Bestand blicken.
///
/// Reine Anzeige: Was die Knöpfe auslösen, entscheidet der Aufrufer.
class ArbeitsplatzUebergabeScreen extends StatelessWidget {
  final UebergabeStand stand;

  /// „Übernehmen" — nur vorhanden, wenn es ein Angebot gibt.
  final VoidCallback onUebernehmen;

  /// „Eigenen Stand behalten" bzw. „Verstanden": weiter in die Anwendung.
  final VoidCallback onWeiter;

  /// Läuft gerade eine Übernahme? Dann sind beide Wege gesperrt — ein zweiter
  /// Klick würde denselben Bestand ein zweites Mal überschreiben.
  final bool laeuft;

  /// Meldung eines fehlgeschlagenen Übernahmeversuchs.
  final String? fehler;

  const ArbeitsplatzUebergabeScreen({
    super.key,
    required this.stand,
    required this.onUebernehmen,
    required this.onWeiter,
    this.laeuft = false,
    this.fehler,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de'),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Builder(builder: _inhalt),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inhalt(BuildContext context) {
    final lauf = stand.letzteSicherung;
    final angebot = stand.angebot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lauf != null && lauf.offenerFehler) ...[
          SicherungsFehlerKarte(lauf: lauf),
          const SizedBox(height: 24),
        ],
        if (angebot != null) ...[
          UebergabeAngebotKarte(
            angebot: angebot,
            eigenerStand: stand.eigenerStandGesichertAm,
          ),
          const SizedBox(height: 24),
        ],
        if (fehler != null) ...[
          Text(
            fehler!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (laeuft)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Stand wird übernommen …'),
              ],
            ),
          )
        else
          ..._knoepfe(angebot != null),
      ],
    );
  }

  List<Widget> _knoepfe(bool mitAngebot) {
    if (!mitAngebot) {
      return [
        FilledButton(onPressed: onWeiter, child: const Text('Verstanden')),
      ];
    }
    return [
      FilledButton.icon(
        onPressed: onUebernehmen,
        icon: const Icon(Icons.cloud_download_outlined),
        label: const Text('Stand übernehmen'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onWeiter,
        child: const Text('Eigenen Stand behalten'),
      ),
    ];
  }
}
