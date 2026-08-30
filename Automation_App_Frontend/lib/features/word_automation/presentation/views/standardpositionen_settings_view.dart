import 'dart:async';

import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/tabellenkopf_farbe_field.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/standardpositionen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Reiter „Schadensaufstellung" in den Einstellungen. Gehört fachlich zum
/// Feature `word_automation` und wird — wie die Reiter aus `mailbox` und
/// `backup` — von der Einstellungsseite nur eingehängt.
///
/// Oben die Titelzeilen-Farbe (liegt im Kanzlei-Einstellungssatz und speichert
/// beim Auswählen sofort, wie die Wahl im Reiter „Darstellung"), darunter der
/// Editor der Standardpositionen mit der Tabellen-Vorschau. Die Vorschau folgt
/// dem Farbfeld **live** — auch einem noch ungespeicherten Wert.
class StandardpositionenSettingsView extends StatefulWidget {
  const StandardpositionenSettingsView({super.key});

  @override
  State<StandardpositionenSettingsView> createState() =>
      _StandardpositionenSettingsViewState();
}

class _StandardpositionenSettingsViewState
    extends State<StandardpositionenSettingsView> {
  static final RegExp _hexMuster = RegExp(r'^[0-9A-F]{6}$');

  final FormControl<String> _farbe = FormControl<String>(
    value: KanzleiSettings.defaultTabellenkopfFarbeHex,
    validators: [
      Validators.required,
      Validators.pattern(r'^#?[0-9a-fA-F]{6}$'),
    ],
  );
  late final FormGroup _form = FormGroup({'tabellenkopfFarbeHex': _farbe});

  bool _farbeUebernommen = false;
  StreamSubscription<String?>? _farbAbo;

  @override
  void initState() {
    super.initState();
    _farbAbo = _farbe.valueChanges.listen(_speichereFarbe);
  }

  @override
  void dispose() {
    _farbAbo?.cancel();
    super.dispose();
  }

  static String _normalisiert(String? wert) =>
      (wert ?? '').trim().replaceFirst('#', '').toUpperCase();

  /// Speichert eine gültige Farbe sofort — ein Farbfeld-Klick soll gelten,
  /// ohne dass daneben ein zweiter Speichern-Knopf um Aufmerksamkeit
  /// konkurriert. Unvollständige Hex-Eingaben werden still übergangen; der
  /// unveränderte Wert auch, sonst speicherte schon das Befüllen beim Laden.
  void _speichereFarbe(String? wert) {
    final hex = _normalisiert(wert);
    if (!_hexMuster.hasMatch(hex)) return;

    final bloc = context.read<KanzleiSettingsBloc>();
    final stand = bloc.state;
    if (stand is! KanzleiSettingsLoaded) return;
    if (_normalisiert(stand.settings.tabellenkopfFarbeHex) == hex) return;

    bloc.add(SaveTabellenkopfFarbeEvent(hex));
  }

  @override
  Widget build(BuildContext context) {
    return StandNachziehen<KanzleiSettingsBloc, KanzleiSettingsState>(
      // Auch der Stand, der beim Aufgehen schon dasteht (siehe
      // stand_nachziehen.dart). emitEvent: false, damit das Befüllen nicht
      // durch den valueChanges-Hörer als „Änderung" gespeichert wird.
      nachziehen: (context, stand) {
        if (_farbeUebernommen || stand is! KanzleiSettingsLoaded) return;
        _farbeUebernommen = true;
        _farbe.updateValue(
          stand.settings.tabellenkopfFarbeHex,
          emitEvent: false,
        );
      },
      beiUebergang: (context, stand) {
        if (stand is KanzleiSettingsLoaded &&
            stand.gespeichert == KanzleiSettingsBereich.schadensaufstellung) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Tabellenfarbe gespeichert.')),
            );
        }
      },
      builder: (context, stand) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ReactiveForm(
              formGroup: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farbe der Titelzeile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gilt für die Schadensaufstellung in den erzeugten '
                    'Word-Dokumenten; die Zebra-Streifen der Positionszeilen '
                    'werden daraus abgeleitet. Eine gewählte Farbe wird '
                    'sofort gespeichert.',
                  ),
                  const SizedBox(height: 12),
                  const TabellenkopfFarbeField(),
                  const SizedBox(height: 32),
                  Text(
                    'Standardpositionen der Schadensaufstellung',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mit diesen Positionen startet jede neu begonnene '
                    'Schadensaufstellung. Ein Betrag ist optional: Er wird nur '
                    'vorbelegt und bleibt im Wizard änderbar; Positionen ohne '
                    'Betrag erscheinen nicht im erzeugten Schreiben.',
                  ),
                  const SizedBox(height: 16),
                  // Die Vorschau folgt dem Feld live; erst ein gültiger Wert
                  // wechselt die Farbe, unterwegs bleibt die gespeicherte.
                  ReactiveValueListenableBuilder<String>(
                    formControlName: 'tabellenkopfFarbeHex',
                    builder: (context, control, _) {
                      final eingabe = _normalisiert(control.value);
                      final headerColorHex = _hexMuster.hasMatch(eingabe)
                          ? eingabe
                          : stand is KanzleiSettingsLoaded
                          ? stand.settings.tabellenkopfFarbeHex
                          : null;
                      return StandardpositionenEditor(
                        headerColorHex: headerColorHex,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
