import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_item_controllers.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schadensposition_hinzufuegen_menue.dart';
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

  /// Womit eine neu begonnene Aufstellung startet (§4.4): die in den
  /// Einstellungen konfigurierten Positionen; ohne Konfiguration die Vorgabe.
  final List<StandardSchadensposition> standardpositionen;

  const DamageListingForm({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.standardpositionen = StandardSchadenspositionen.vorgabe,
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
      text: betragAlsEingabe(initial?.gebuehrensatz ?? 1.3),
    );
    _geschaeftsgebuehrOverrideController = TextEditingController(
      text: initial?.geschaeftsgebuehrOverride != null
          ? betragAlsEingabe(initial!.geschaeftsgebuehrOverride!)
          : '',
    );
    _auslagenpauschaleOverrideController = TextEditingController(
      text: initial?.auslagenpauschaleOverride != null
          ? betragAlsEingabe(initial!.auslagenpauschaleOverride!)
          : '',
    );
    // Ohne gespeicherten Stand stehen die Standardpositionen da (§4.4) —
    // vorbelegt in der Bezeichnung, im Betrag nur, wenn in den Einstellungen
    // einer hinterlegt ist. Ein gespeicherter Stand gewinnt: Der Anwalt hat
    // ihn erfasst, er wird nicht überschrieben.
    _items = initial == null || initial.items.isEmpty
        ? [
            for (final position in widget.standardpositionen)
              DamageItemControllers(
                description: position.bezeichnung,
                amount: position.betrag != null
                    ? betragAlsEingabe(position.betrag!)
                    : null,
              ),
          ]
        : [
            for (final item in initial.items)
              DamageItemControllers(
                description: item.description,
                amount: betragAlsEingabe(item.amount),
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
    // Einmal je Aufbau lesen statt einmal je Verwendung — im Aufbau standen
    // sonst so viele Parses wie Zeilen mal Verwendungen. Dass `_emit` seine
    // eigene Lesung braucht, bleibt: Es läuft aus einem Rückruf heraus, nicht
    // im Aufbau, und darf nicht auf einem veralteten Stand rechnen.
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
          child: SchadenspositionHinzufuegenMenue(
            standardpositionen: widget.standardpositionen,
            // Erst beim Aufklappen gelesen, direkt aus den Feldern: Ein hier
            // eingesammelter Satz stünde auf dem Stand des letzten Aufbaus.
            vorhandeneBezeichnungen: () => {
              for (final item in _items) item.description.text.trim(),
            },
            // Mit _emit(), obwohl die neue Zeile ohne Betrag ohnehin aus der
            // Aufstellung fällt: Das Löschen daneben meldet auch. Hinge das
            // Melden daran, dass die Prüfung heute nur Beträge beanstandet,
            // bliebe die erste Regel über eine Bezeichnung an einer über das
            // Menü angelegten Zeile stumm — und zwar genau bis der Anwalt
            // zufällig ihr Betragsfeld anfasst.
            // Der Betrag kommt mit zurück, wenn zur Position einer
            // konfiguriert ist — die zurückgeholte Zeile sieht aus wie die
            // ursprünglich vorbelegte.
            onGewaehlt: (position) {
              setState(
                () => _items.add(
                  DamageItemControllers(
                    description: position?.bezeichnung,
                    amount: position?.betrag != null
                        ? betragAlsEingabe(position!.betrag!)
                        : null,
                  ),
                ),
              );
              _emit();
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
        betrag: betragAusEingabe(item.amount.text),
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
        gebuehrensatz: betragAusEingabe(_gebuehrensatzController.text) ?? 1.3,
        // applyVat wird vom Wizard aus der Vorsteuer-Checkbox gesetzt.
        geschaeftsgebuehrOverride: betragAusEingabe(
          _geschaeftsgebuehrOverrideController.text,
        ),
        auslagenpauschaleOverride: betragAusEingabe(
          _auslagenpauschaleOverrideController.text,
        ),
      ),
      schadenspositionenFehler(zeilen),
    );
  }
}
