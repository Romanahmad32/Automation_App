import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:flutter/material.dart';

/// Eingabe der Schadensaufstellung im Schadensaufstellungs-Schritt des Wizards:
/// Schadenspositionen und Gebührensatz. Die Umsatzsteuer-Option (applyVat)
/// kommt aus der Vorsteuer-Checkbox im Ausfüll-Schritt und wird hier nicht mehr
/// erfasst. Meldet bei jeder Änderung den aktuellen Stand über [onChanged].
class DamageListingForm extends StatefulWidget {
  final ValueChanged<DamageListing> onChanged;

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
  late final List<_DamageItemControllers> _items;
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
        ? [_DamageItemControllers()]
        : [
            for (final item in initial.items)
              _DamageItemControllers(
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
                    decoration: const InputDecoration(
                      labelText: 'Betrag (€)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _emit(),
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
              setState(() => _items.add(_DamageItemControllers()));
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

  void _emit() {
    final items = [
      for (final item in _items)
        if (item.description.text.trim().isNotEmpty &&
            _parseAmount(item.amount.text) != null)
          DamageItem(
            description: item.description.text.trim(),
            amount: _parseAmount(item.amount.text)!,
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
    );
  }

  static double? _parseAmount(String text) =>
      double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));

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

class _DamageItemControllers {
  final TextEditingController description;
  final TextEditingController amount;

  _DamageItemControllers({String? description, String? amount})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}
