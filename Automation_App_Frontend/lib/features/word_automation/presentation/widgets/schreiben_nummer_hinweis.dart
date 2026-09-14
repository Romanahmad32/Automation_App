import 'package:flutter/material.dart';

/// Die Zeile über dem Ausfüll-Formular, sobald zum Vorgang ein Schreiben
/// **gespeichert** ist: zwei [ChoiceChip]s fragen, ob das nächste Schreiben
/// die gespeicherte Fassung ersetzt oder als weitere daneben tritt (§4.9).
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
/// Solange **nichts gespeichert** ist, erscheint die Zeile nicht: Ein bloß
/// erzeugtes Schreiben liegt im Arbeitsordner, den die nächste Ablage ohnehin
/// wegräumt — da gibt es nichts zu ersetzen und nichts zu entscheiden.
///
/// Gestalt seit dem 14.09.2026 („Variante B"): zwei Zeilen statt einer
/// achtzeiligen Karte mit [SegmentedButton] — die Wahl selbst ist eine Wahl
/// zwischen zwei Möglichkeiten (siehe `auswahl_themes.dart`), keine Ansicht,
/// deshalb [ChoiceChip] statt [SegmentedButton]. Der Dateiname der
/// gespeicherten Fassung steht nur noch in der Unterzeile, nicht mehr in
/// einer eigenen Zeile darüber.
class SchreibenNummerHinweis extends StatelessWidget {
  /// Der Satz, den der Ausfüllschritt über dem Erstellen-Knopf zeigt, solange
  /// die Wahl aussteht. Steht hier und nicht dort, damit Leiste und Hinweis
  /// dieselbe Sprache sprechen — und der Test beides an einer Zeichenkette
  /// festmachen kann.
  static const wahlFehltHinweis =
      'Bitte oben wählen, ob dies eine Korrektur des gespeicherten Schreibens '
      'ist oder ein neues Schreiben.';

  /// Beschriftung der Kopfzeile vor den beiden Chips.
  static const kopfzeile = 'Dieses Schreiben ist …';

  /// Beschriftung des Chips für die Korrektur.
  static const korrekturChipLabel = 'Korrektur des letzten Schreibens';

  /// Beschriftung des Chips für ein neues Schreiben.
  static const neuChipLabel = 'Neues Schreiben';

  /// Nummer des zuletzt **gespeicherten** Schreibens (mindestens 1).
  final int bisherigeNummer;

  /// Pfad des zuletzt gespeicherten Schreibens; nur der Dateiname wird gezeigt.
  /// Null, wenn keiner bekannt ist — dann nennt die Unterzeile nur die Nummer.
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
  /// Brauchbares übrig bleibt.
  static String dateinameAus(String? pfad) {
    final roh = (pfad ?? '').trim();
    if (roh.isEmpty) return '';
    return roh.split(RegExp(r'[\\/]')).last;
  }

  /// Die Unterzeile — vor der Wahl nur die Nummer, danach die Wirkung. Der
  /// Dateiname erscheint nur, wenn er zur gerade sichtbaren Aussage etwas
  /// beiträgt: bei der Korrektur, die ihn ersetzt.
  String get _unterzeile {
    final dateiname = dateinameAus(letzterDokumentPfad);
    return switch (neuesSchreiben) {
      null => 'Zu diesem Vorgang ist Nr. $bisherigeNummer gespeichert.',
      false =>
        dateiname.isEmpty
            ? 'Ersetzt die gespeicherte Fassung (Nr. $bisherigeNummer).'
            : 'Ersetzt „$dateiname" (Nr. $bisherigeNummer).',
      true => 'Wird als Nr. ${bisherigeNummer + 1} abgelegt.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(kopfzeile, style: texte.bodyMedium),
            ChoiceChip(
              label: const Text(korrekturChipLabel),
              selected: neuesSchreiben == false,
              onSelected: (_) => onGeaendert(false),
            ),
            ChoiceChip(
              label: const Text(neuChipLabel),
              selected: neuesSchreiben == true,
              onSelected: (_) => onGeaendert(true),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _unterzeile,
          style: texte.bodySmall?.copyWith(color: farben.outline),
        ),
      ],
    );
  }
}
