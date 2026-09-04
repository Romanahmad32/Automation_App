import 'dart:async';

import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
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
          Rueckmeldung.zeigeErfolg(context, 'Tabellenfarbe gespeichert.');
        }
      },
      builder: (context, stand) => ReactiveForm(
        formGroup: _form,
        // Einspaltig und breiter als die übrigen Reiter: Der Editor zeigt die
        // Tabelle so, wie sie im Dokument steht — in 760 px bricht sie um und
        // die Vorschau taugt nicht mehr als Vorschau.
        child: EinstellungenReiter(
          breiteEinspaltig: 1000,
          links: [
            const FormSection(
              icon: Icons.format_color_fill_outlined,
              title: 'Farbe der Titelzeile',
              subtitle:
                  'Gilt für die Schadensaufstellung in den erzeugten '
                  'Word-Dokumenten; die Zebra-Streifen der Positionszeilen '
                  'werden daraus abgeleitet. Eine gewählte Farbe wird '
                  'sofort gespeichert.',
              children: [TabellenkopfFarbeField()],
            ),
            FormSection(
              icon: Icons.table_rows_outlined,
              title: 'Standardpositionen der Schadensaufstellung',
              subtitle:
                  'Mit diesen Positionen startet jede neu begonnene '
                  'Schadensaufstellung. Ein Betrag ist optional: Er wird nur '
                  'vorbelegt und bleibt im Wizard änderbar; Positionen ohne '
                  'Betrag erscheinen nicht im erzeugten Schreiben.',
              children: [
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
          ],
        ),
      ),
    );
  }
}
