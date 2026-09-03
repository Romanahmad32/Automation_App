import 'package:flutter/material.dart';

/// Die Leiste über dem Ausfüll-Formular ab dem **zweiten** Schreiben zu einem
/// Vorgang: „Korrektur von Nr. 1" oder „Neues Schreiben · Nr. 2" (§4.9).
///
/// Warum gefragt und nicht geraten: Beide Fälle sehen von aussen gleich aus —
/// der Anwalt füllt dasselbe Formular aus und drückt denselben Knopf. Rät die
/// App falsch, geht das in beide Richtungen schief. Eine als Korrektur
/// missdeutete Mahnung überschreibt das Anspruchsschreiben, das schon in der
/// Akte liegt; eine als neues Schreiben missdeutete Korrektur legt drei
/// Fassungen desselben Briefes nebeneinander. Die Änderungszeit der Datei
/// unterscheidet das nicht (siehe `neuerzeugung_bestaetigung.dart`, die etwas
/// anderes prüft: ob jemand in Word nachgebessert hat).
///
/// Beim **ersten** Schreiben eines Vorgangs erscheint die Leiste nicht — dort
/// gibt es nichts zu entscheiden, die Nummer ist die 1.
class SchreibenNummerHinweis extends StatelessWidget {
  /// Nummer des zuletzt erzeugten Schreibens (mindestens 1).
  final int bisherigeNummer;

  /// Pfad des zuletzt erzeugten Schreibens; nur der Dateiname wird gezeigt.
  /// Null, wenn keiner bekannt ist — dann entfällt die Zeile.
  final String? letzterDokumentPfad;

  /// Die aktuelle Wahl: true = neues Schreiben, false = Korrektur.
  final bool neuesSchreiben;

  final ValueChanged<bool> onGeaendert;

  const SchreibenNummerHinweis({
    super.key,
    required this.bisherigeNummer,
    required this.neuesSchreiben,
    required this.onGeaendert,
    this.letzterDokumentPfad,
  });

  /// Der Dateiname aus einem Pfad, ohne Verzeichnis. Leer, wenn nichts
  /// Brauchbares übrig bleibt — die Zeile entfällt dann.
  static String dateinameAus(String? pfad) {
    final roh = (pfad ?? '').trim();
    if (roh.isEmpty) return '';
    return roh.split(RegExp(r'[\\/]')).last;
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final letzter = dateinameAus(letzterDokumentPfad);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: farben.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.numbers_outlined, color: farben.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Zu diesem Vorgang gibt es bereits '
                    '${bisherigeNummer == 1 ? 'ein Schreiben' : '$bisherigeNummer Schreiben'}.',
                    style: texte.bodyMedium?.copyWith(
                      color: farben.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (letzter.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  'Zuletzt: $letzter',
                  style: texte.bodySmall?.copyWith(
                    color: farben.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text('Korrektur von Nr. $bisherigeNummer'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text('Neues Schreiben · Nr. ${bisherigeNummer + 1}'),
                  ),
                ],
                selected: {neuesSchreiben},
                onSelectionChanged: (auswahl) => onGeaendert(auswahl.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
