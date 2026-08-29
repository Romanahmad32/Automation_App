import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_item_controllers.dart';
import 'package:flutter/material.dart';

/// Eingabe der Schadensaufstellung im Schadensaufstellungs-Schritt des Wizards:
/// Schadenspositionen und Gebührensatz. Die Umsatzsteuer-Option (applyVat)
/// kommt aus der Vorsteuer-Checkbox im Ausfüll-Schritt und wird hier nicht mehr
/// erfasst. Meldet bei jeder Änderung den aktuellen Stand über [onChanged].
class DamageListingForm extends StatefulWidget {
  /// Meldet den erfassten Stand **und** die Beanstandungen, die das Formular an
  /// seinen Zeilen sieht.
  ///
  /// Beides zusammen und nicht nacheinander: Die Aufstellung enthält nur
  /// vollständige Zeilen, die Beanstandungen betreffen aber auch angefangene
  /// (eine Zeile mit `-250` und leerer Bezeichnung). Wer nur die Aufstellung
  /// bekäme, hielte diesen Fall für einwandfrei — und genau das war er nicht.
  final void Function(DamageListing aufstellung, List<String> fehler) onChanged;

  /// Vorbelegung, damit beim Zurück- und wieder Vorblättern im Wizard die
  /// bereits erfassten Positionen erhalten bleiben.
  final DamageListing? initialValue;

  const DamageListingForm({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  @override
  State<DamageListingForm> createState() => _DamageListingFormState();
}

class _DamageListingFormState extends State<DamageListingForm> {
  late final List<DamageItemControllers> _items;
  late final TextEditingController _gebuehrensatzController;
  late final TextEditingController _geschaeftsgebuehrOverrideController;
  late final TextEditingController _auslagenpauschaleOverrideController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _gebuehrensatzController = TextEditingController(
      text: _formatNumber(initial?.gebuehrensatz ?? 1.3),
    );
    _geschaeftsgebuehrOverrideController = TextEditingController(
      text: initial?.geschaeftsgebuehrOverride != null
          ? _formatNumber(initial!.geschaeftsgebuehrOverride!)
          : '',
    );
    _auslagenpauschaleOverrideController = TextEditingController(
      text: initial?.auslagenpauschaleOverride != null
          ? _formatNumber(initial!.auslagenpauschaleOverride!)
          : '',
    );
    _items = initial == null || initial.items.isEmpty
        ? [DamageItemControllers()]
        : [
            for (final item in initial.items)
              DamageItemControllers(
                description: item.description,
                amount: _formatNumber(item.amount),
              ),
          ];
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _gebuehrensatzController.dispose();
    _geschaeftsgebuehrOverrideController.dispose();
    _auslagenpauschaleOverrideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Je Zeile einmal lesen statt einmal je Verwendung: Der Betrag wurde sonst
    // bei jedem Tastendruck mehrfach geparst — einmal für den errorText und
    // zweimal in _emit.
    final zeilen = _zeilen();

    return Column(
      children: [
        for (final (index, item) in _items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: item.description,
                    decoration: const InputDecoration(
                      labelText: 'Schadensposition',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: item.amount,
                    decoration: InputDecoration(
                      labelText: 'Betrag (€)',
                      border: const OutlineInputBorder(),
                      // Die Beanstandung steht an der Zeile, die sie auslöst —
                      // nicht als Sammelmeldung über der Aufstellung.
                      errorText: betragUnzulaessig(zeilen[index].betrag)
                          ? negativerBetragHinweis
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // setState, weil sich mit dem Text auch der errorText
                    // ändert; _emit() allein baut nur den Rest der Seite neu.
                    onChanged: (_) {
                      setState(() {});
                      _emit();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Position entfernen',
                  onPressed: _items.length > 1
                      ? () {
                          setState(() => _items.removeAt(index).dispose());
                          _emit();
                        }
                      : null,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Position hinzufügen'),
            onPressed: () {
              setState(() => _items.add(DamageItemControllers()));
            },
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gebuehrensatzController,
          decoration: const InputDecoration(
            labelText: 'Gebührensatz (Geschäftsgebühr)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _emit(),
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
              controller: _geschaeftsgebuehrOverrideController,
              decoration: const InputDecoration(
                labelText: 'Geschäftsgebühr überschreiben (€)',
                helperText:
                    'Ersetzt Wertgebühr × Gebührensatz (Nr. 2300 VV RVG)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _auslagenpauschaleOverrideController,
              decoration: const InputDecoration(
                labelText: 'Auslagenpauschale überschreiben (€)',
                helperText:
                    'Ersetzt die Pauschale nach Nr. 7002 VV RVG (20 %, max. 20 €)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ],
    );
  }

  /// Der aktuelle Stand aller Zeilen — auch der angefangenen. Grundlage sowohl
  /// für die Markierung an der Zeile als auch für das Verdikt, das nach oben
  /// geht; beide sehen damit garantiert dasselbe.
  List<Schadenspositionszeile> _zeilen() => [
    for (final item in _items)
      (
        bezeichnung: item.description.text,
        betrag: _parseAmount(item.amount.text),
      ),
  ];

  /// Meldet Stand und Beanstandungen nach oben.
  ///
  /// Halbfertige Zeilen (keine Bezeichnung, kein lesbarer Betrag) bleiben aus
  /// der Aufstellung draußen — sie sollen nicht in der Vorschau auftauchen,
  /// während getippt wird. Beanstandet werden sie trotzdem: Das Verdikt läuft
  /// über **alle** Zeilen, sonst bliebe eine Zeile mit `-250` und leerer
  /// Bezeichnung sichtbar rot und „Dokument erstellen" trotzdem frei.
  void _emit() {
    final zeilen = _zeilen();
    final items = [
      for (final zeile in zeilen)
        if (zeile.bezeichnung.trim().isNotEmpty && zeile.betrag != null)
          DamageItem(
            description: zeile.bezeichnung.trim(),
            amount: zeile.betrag!,
          ),
    ];

    widget.onChanged(
      DamageListing(
        items: items,
        gebuehrensatz: _parseAmount(_gebuehrensatzController.text) ?? 1.3,
        // applyVat wird vom Wizard aus der Vorsteuer-Checkbox gesetzt.
        geschaeftsgebuehrOverride: _parseAmount(
          _geschaeftsgebuehrOverrideController.text,
        ),
        auslagenpauschaleOverride: _parseAmount(
          _auslagenpauschaleOverrideController.text,
        ),
      ),
      schadenspositionenFehler(zeilen),
    );
  }

  /// `-0,0` wird zu `0.0` normalisiert: Es ist numerisch null, gilt also nicht
  /// als negativ (`-0.0 < 0` ist `false`) — würde aber als `-0.0` im JSON an das
  /// Backend hinausgehen und der Zusage „kein negativer Betrag" wörtlich
  /// widersprechen.
  static double? _parseAmount(String text) {
    final wert = double.tryParse(
      text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (wert == 0) return 0.0;
    return wert;
  }

  /// Zahl als deutsche Eingabe formatieren (Komma, ohne überflüssige Nullen).
  static String _formatNumber(double value) {
    var text = value.toStringAsFixed(2).replaceAll('.', ',');
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith(',')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }
}
