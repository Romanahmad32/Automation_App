import 'package:flutter/material.dart';

/// Die Leiste über dem Ausfüll-Formular, sobald zum Vorgang ein Schreiben
/// **gespeichert** ist: „Korrektur von Nr. 1" oder „Neues Schreiben · Nr. 2"
/// (§4.9).
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
/// Deshalb ist auch **nichts vorbelegt** (#133): Eine überlesene Vorauswahl
/// „Korrektur" ist dasselbe Raten, nur mit dem Anschein einer Entscheidung.
/// Solange nichts gewählt ist, sperrt der Ausfüllschritt das Erstellen — und
/// sagt darüber, was fehlt ([wahlFehltHinweis]), statt den Knopf stumm zu
/// lassen (vgl. #130).
///
/// Solange **nichts gespeichert** ist, erscheint die Leiste nicht: Ein bloß
/// erzeugtes Schreiben liegt im Arbeitsordner, den die nächste Ablage ohnehin
/// wegräumt — da gibt es nichts zu ersetzen und nichts zu entscheiden.
class SchreibenNummerHinweis extends StatelessWidget {
  /// Der Satz, den der Ausfüllschritt über dem Erstellen-Knopf zeigt, solange
  /// die Wahl aussteht. Steht hier und nicht dort, damit Leiste und Hinweis
  /// dieselbe Sprache sprechen — und der Test beides an einer Zeichenkette
  /// festmachen kann.
  static const wahlFehltHinweis =
      'Bitte oben wählen, ob dies eine Korrektur des gespeicherten Schreibens '
      'ist oder ein neues Schreiben.';

  /// Nummer des zuletzt **gespeicherten** Schreibens (mindestens 1).
  final int bisherigeNummer;

  /// Pfad des zuletzt gespeicherten Schreibens; nur der Dateiname wird gezeigt.
  /// Null, wenn keiner bekannt ist — dann entfällt die Zeile.
  final String? letzterDokumentPfad;

  /// Die aktuelle Wahl: true = neues Schreiben, false = Korrektur,
  /// **null = noch nicht gewählt**.
  final bool? neuesSchreiben;

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

  /// Was eine Korrektur bewirkt — ein Satz, keine Andeutung.
  static const folgeKorrektur =
      'Eine Korrektur ersetzt die gespeicherte Fassung.';

  /// Was ein neues Schreiben bewirkt.
  static const folgeNeu = 'Ein neues Schreiben legt eine weitere daneben.';

  /// Die Folgen, die gerade zu lesen sind: vor der Wahl **beide** — das ist die
  /// Auskunft, auf der entschieden wird —, danach nur noch die, die eintritt.
  List<String> get _folgen => switch (neuesSchreiben) {
    null => const [folgeKorrektur, folgeNeu],
    true => const [folgeNeu],
    false => const [folgeKorrektur],
  };

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final letzter = dateinameAus(letzterDokumentPfad);
    final wahl = neuesSchreiben;

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
                    bisherigeNummer == 1
                        ? 'Zu diesem Vorgang ist bereits ein Schreiben '
                              'gespeichert.'
                        : 'Zu diesem Vorgang sind bereits $bisherigeNummer '
                              'Schreiben gespeichert.',
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
                  'Gespeichert als Nr. $bisherigeNummer: $letzter',
                  style: texte.bodySmall?.copyWith(
                    color: farben.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final folge in _folgen)
                    Text(
                      folge,
                      style: texte.bodySmall?.copyWith(
                        color: farben.onTertiaryContainer,
                      ),
                    ),
                ],
              ),
            ),
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
                // Leere Menge = noch nicht gewählt. `emptySelectionAllowed`
                // erlaubt sie überhaupt erst; ohne das zeichnete der Knopf
                // zwangsweise ein Feld als gewählt und behauptete eine
                // Entscheidung, die niemand getroffen hat.
                emptySelectionAllowed: true,
                selected: wahl == null ? const <bool>{} : {wahl},
                onSelectionChanged: (auswahl) {
                  // Ein zweiter Druck auf dasselbe Feld leert die Auswahl.
                  // Zurück auf „nichts gewählt" zu fallen wäre kein Fortschritt
                  // — die getroffene Wahl bleibt dann einfach stehen.
                  if (auswahl.isEmpty) return;
                  onGeaendert(auswahl.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
