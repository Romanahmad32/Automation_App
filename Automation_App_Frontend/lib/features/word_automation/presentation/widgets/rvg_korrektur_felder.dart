import 'package:automation_app/features/word_automation/presentation/utils/rvg_felder_pruefung.dart';
import 'package:flutter/material.dart';

/// Die drei Eingaben unter der Positionsliste: Gebührensatz und die beiden
/// Felder, mit denen sich die RVG-Berechnung von Hand korrigieren lässt.
///
/// Eigener Baustein und nicht mehr Teil von `DamageListingForm`: Mit der
/// Prüfung an der Zeile trägt jedes der drei Felder jetzt eine eigene
/// Beanstandung, und das Formular lag damit über der Längengrenze. Der Schnitt
/// verläuft dort, wo er ohnehin gehört — Positionen hier, RVG-Kosten dort.
///
/// Bewusst zustandslos: Die Controller gehören dem Formular (es liest sie beim
/// Melden nach oben), und [onChanged] baut es neu auf. So sieht die Markierung
/// am Feld garantiert denselben Stand wie das Verdikt über dem Knopf.
class RvgKorrekturFelder extends StatelessWidget {
  final TextEditingController gebuehrensatz;
  final TextEditingController geschaeftsgebuehr;
  final TextEditingController auslagenpauschale;

  /// Muss den umgebenden Aufbau erneuern (`setState`) **und** nach oben melden:
  /// Mit dem Text ändert sich auch der `errorText`.
  final VoidCallback onChanged;

  const RvgKorrekturFelder({
    super.key,
    required this.gebuehrensatz,
    required this.geschaeftsgebuehr,
    required this.auslagenpauschale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: gebuehrensatz,
        decoration: InputDecoration(
          labelText: '$gebuehrensatzFeldName (Geschäftsgebühr)',
          // Die Grenze steht im Hinweistext und nicht erst in der
          // Fehlermeldung: Wer sie vorher liest, verletzt sie seltener.
          helperText: 'Üblich 1,3; zulässig 0,1 bis 10 — leer lassen für 1,3',
          border: const OutlineInputBorder(),
          errorText: gebuehrensatzFehler(gebuehrensatz.text),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
      ),
      const SizedBox(height: 8),
      // Manuelle Korrektur der RVG-Berechnung: leer = automatisch nach der
      // amtlichen Gebührentabelle (Anlage 2 zu § 13 RVG) rechnen.
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('RVG-Berechnung korrigieren'),
        subtitle: const Text(
          'Leer lassen für die automatische Berechnung nach § 13 RVG',
        ),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          TextField(
            controller: geschaeftsgebuehr,
            decoration: InputDecoration(
              labelText: '$geschaeftsgebuehrFeldName (€)',
              helperText: 'Ersetzt Wertgebühr × Gebührensatz (Nr. 2300 VV RVG)',
              border: const OutlineInputBorder(),
              errorText: korrekturbetragFehler(geschaeftsgebuehr.text),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: auslagenpauschale,
            decoration: InputDecoration(
              labelText: '$auslagenpauschaleFeldName (€)',
              helperText:
                  'Ersetzt die Pauschale nach Nr. 7002 VV RVG (20 %, max. 20 €)',
              border: const OutlineInputBorder(),
              errorText: korrekturbetragFehler(auslagenpauschale.text),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    ],
  );
}
