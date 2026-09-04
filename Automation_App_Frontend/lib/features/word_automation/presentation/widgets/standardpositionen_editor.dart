import 'package:automation_app/core/general_widgets/form/speichern_button.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_item_controllers.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/standardpositionen_vorschau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Editor der Standardpositionen in den Einstellungen (§4.4): Bezeichnung und
/// optional ein vorbelegter Betrag je Zeile, darunter die Vorschau, wie die
/// Schadensaufstellung damit startet. Gespeichert wird die komplette Liste
/// über den [StandardpositionenCubit].
class StandardpositionenEditor extends StatefulWidget {
  /// Titelzeilen-Farbe für die Vorschau (aus den Kanzlei-Einstellungen).
  final String? headerColorHex;

  const StandardpositionenEditor({super.key, this.headerColorHex});

  @override
  State<StandardpositionenEditor> createState() =>
      _StandardpositionenEditorState();
}

class _StandardpositionenEditorState extends State<StandardpositionenEditor>
    with AutomaticKeepAliveClientMixin {
  List<DamageItemControllers> _zeilen = [];
  bool _uebernommen = false;

  // Beim Tab-Wechsel verwirft die TabBarView den State sonst, der Cubit steht
  // auf seinem letzten Stand, und ungespeicherte Eingaben wären weg.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final zeile in _zeilen) {
      zeile.dispose();
    }
    super.dispose();
  }

  /// Füllt die Zeilen aus einem Bloc-Stand. Die alten Controller werden erst
  /// nach dem Frame freigegeben: Die noch aufgebauten Textfelder melden sich
  /// beim Neuaufbau von ihnen ab — auf einem bereits freigegebenen Controller
  /// wäre genau das der Absturz.
  void _fuelle(List<StandardSchadensposition> positionen) {
    final alte = _zeilen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final zeile in alte) {
        zeile.dispose();
      }
    });
    _zeilen = [
      for (final position in positionen)
        DamageItemControllers(
          description: position.bezeichnung,
          amount: position.betrag != null
              ? betragAlsEingabe(position.betrag!)
              : null,
        ),
    ];
  }

  /// Übernimmt den Bloc-Stand in die Felder — beim Aufgehen, nach dem Laden
  /// und nach einem erfolgreichen Speichern (dann normalisiert, wie das
  /// Backend ihn abgelegt hat). Nicht mitten im Tippen: Nach dem ersten
  /// geladenen Stand zieht nur noch ein Speichern nach.
  void _nachziehen(BuildContext context, StandardpositionenStand stand) {
    if (stand.speichert) return;
    if (_uebernommen && !stand.gespeichert) return;
    _uebernommen = _uebernommen || stand.geladen;
    _fuelle(stand.positionen);
  }

  List<StandardSchadensposition> _positionen() => [
    for (final zeile in _zeilen)
      if (zeile.description.text.trim().isNotEmpty)
        StandardSchadensposition(
          bezeichnung: zeile.description.text.trim(),
          betrag: betragAusEingabe(zeile.amount.text),
        ),
  ];

  /// Die Zeile, wie die gemeinsame Pruefung sie sieht — dieselbe Bahn wie in
  /// der Schadensaufstellung des Wizards. Hier ist ein leerer Betrag der
  /// Normalfall („Betrag (€), optional"), ein unlesbarer dagegen dieselbe
  /// stille Falle: Er wurde bisher zu „kein Betrag hinterlegt", und die naechste
  /// Aufstellung startete ohne die Vorbelegung, die der Anwalt eingetippt hatte.
  Schadenspositionszeile _zeile(DamageItemControllers zeile) =>
      schadenspositionszeile(
        bezeichnung: zeile.description.text,
        betragText: zeile.amount.text,
      );

  bool get _hatBeanstandetenBetrag =>
      _zeilen.any((zeile) => betragFehler(_zeile(zeile)) != null);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StandNachziehen<StandardpositionenCubit, StandardpositionenStand>(
      nachziehen: _nachziehen,
      beiUebergang: (context, stand) {
        if (stand.gespeichert) {
          Rueckmeldung.zeigeErfolg(context, 'Standardpositionen gespeichert.');
        } else if (stand.meldung != null) {
          Rueckmeldung.zeigeFehler(context, stand.meldung!);
        }
      },
      builder: (context, stand) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, zeile) in _zeilen.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: zeile.description,
                      decoration: const InputDecoration(
                        labelText: 'Schadensposition',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: zeile.amount,
                      decoration: InputDecoration(
                        labelText: 'Betrag (€), optional',
                        border: const OutlineInputBorder(),
                        errorText: betragFehler(_zeile(zeile)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Position entfernen',
                    onPressed: _zeilen.length > 1
                        ? () =>
                              setState(() => _zeilen.removeAt(index).dispose())
                        : null,
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 16,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Position hinzufügen'),
                onPressed: () =>
                    setState(() => _zeilen.add(DamageItemControllers())),
              ),
              // Füllt nur die Felder — gespeichert ist erst nach „Speichern".
              TextButton.icon(
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Auf die üblichen fünf zurücksetzen'),
                onPressed: () =>
                    setState(() => _fuelle(StandardSchadenspositionen.vorgabe)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Derselbe Knopf wie in jeder anderen Einstellungsmaske
          // (Kanzleidaten, Postfach): rechtsbündig, mit Ring während des
          // Schreibens. Hier stand vorher ein CustomRectangularButton, und
          // damit sah der Speichern-Knopf der Schadensaufstellung als
          // einziger anders aus als der Rest der Einstellungen.
          SpeichernButton(
            speichert: stand.speichert,
            onSpeichern: _hatBeanstandetenBetrag
                ? null
                : () => context.read<StandardpositionenCubit>().speichern(
                    _positionen(),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            'Vorschau',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StandardpositionenVorschau(
            positionen: _positionen(),
            headerColorHex: widget.headerColorHex,
          ),
        ],
      ),
    );
  }
}
