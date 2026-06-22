import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Formular für die Kanzlei-/Anfragerdaten, mit denen der Abschnitt "Anfrager"
/// des Zentralruf-Formulars vorausgefüllt wird.
class AppSettingsView extends StatefulWidget {
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView>
    with AutomaticKeepAliveClientMixin {
  bool _initialized = false;

  // In den Einstellungen liegt diese Ansicht in einem TabBarView neben dem
  // Postfach-Zugang. Ohne KeepAlive verwirft die TabBarView den State beim
  // Tab-Wechsel und baut das Formular leer neu — der Bloc steht dann schon auf
  // "Loaded", der Listener feuert nicht erneut, und die Kanzleidaten würden
  // verschwinden (und beim Speichern mit Defaults überschrieben).
  @override
  bool get wantKeepAlive => true;

  // Eigener Controller, damit die Scrollbar am rechten Seitenrand sitzt
  // (volle Breite) und nicht am Rand der zentrierten Formularspalte.
  final ScrollController _scrollController = ScrollController();

  static const List<String> _anfragertypen =
      KanzleiSettings.gueltigePersonentypen;

  final FormGroup _form = FormGroup({
    'personentyp': FormControl<String>(value: 'Rechtsanwalt'),
    'name': FormControl<String>(validators: [Validators.required]),
    'strasseHausnummer': FormControl<String>(),
    'postleitzahl': FormControl<String>(),
    'ort': FormControl<String>(),
    'emailAdresse': FormControl<String>(validators: [Validators.email]),
    'telefonnummer': FormControl<String>(),
    'laufendeAuftragsnummer': FormControl<String>(
      value: KanzleiSettings.defaultLaufendeAuftragsnummer.toString(),
      validators: [Validators.required, Validators.number()],
    ),
    'abteilung': FormControl<String>(
      value: KanzleiSettings.defaultAbteilung,
      validators: [Validators.required],
    ),
    'tabellenkopfFarbeHex': FormControl<String>(
      value: KanzleiSettings.defaultTabellenkopfFarbeHex,
      validators: [
        Validators.required,
        Validators.pattern(r'^#?[0-9a-fA-F]{6}$'),
      ],
    ),
    'aktenStammordner': FormControl<String>(),
  });

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _patch(KanzleiSettings settings) {
    _form.patchValue({
      // Unbekannte Altwerte bereinigt bereits KanzleiSettings.fromJson;
      // der Fallback hier schützt nur noch vor programmatisch gesetzten Werten.
      'personentyp': _anfragertypen.contains(settings.personentyp)
          ? settings.personentyp
          : KanzleiSettings.defaultPersonentyp,
      'name': settings.name,
      'strasseHausnummer': settings.strasseHausnummer,
      'postleitzahl': settings.postleitzahl,
      'ort': settings.ort,
      'emailAdresse': settings.emailAdresse,
      'telefonnummer': settings.telefonnummer,
      'laufendeAuftragsnummer': settings.laufendeAuftragsnummer.toString(),
      'abteilung': settings.abteilung,
      'tabellenkopfFarbeHex': settings.tabellenkopfFarbeHex,
      'aktenStammordner': settings.aktenStammordner,
    });
  }

  void _save() {
    final value = _form.value;
    String read(String key) => (value[key] as String?)?.trim() ?? '';

    context.read<KanzleiSettingsBloc>().add(
      SaveKanzleiSettingsEvent(
        KanzleiSettings(
          personentyp: read('personentyp'),
          name: read('name'),
          strasseHausnummer: read('strasseHausnummer'),
          postleitzahl: read('postleitzahl'),
          ort: read('ort'),
          emailAdresse: read('emailAdresse'),
          telefonnummer: read('telefonnummer'),
          laufendeAuftragsnummer:
          int.tryParse(read('laufendeAuftragsnummer')) ??
              KanzleiSettings.defaultLaufendeAuftragsnummer,
          abteilung: read('abteilung'),
          tabellenkopfFarbeHex: read(
            'tabellenkopfFarbeHex',
          ).replaceFirst('#', '').toUpperCase(),
          aktenStammordner: read('aktenStammordner'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return BlocConsumer<KanzleiSettingsBloc, KanzleiSettingsState>(
      listener: (context, state) {
        if (state is KanzleiSettingsLoaded) {
          if (!_initialized) {
            _patch(state.settings);
            setState(() => _initialized = true);
          }
          if (state.justSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kanzleidaten gespeichert')),
            );
          }
        } else if (state is KanzleiSettingsError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (!_initialized && state is KanzleiSettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaving = state is KanzleiSettingsLoading;

        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ReactiveForm(
                    formGroup: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        FormSection(
                          icon: Icons.business,
                          title: 'Kanzlei- / Anfragerdaten',
                          subtitle:
                          'Diese Daten füllen den Abschnitt "Anfrager" der '
                              'Zentralruf-Anfrage automatisch aus.',
                          children: [
                            ReactiveDropdownField<String>(
                              formControlName: 'personentyp',
                              decoration: const InputDecoration(
                                labelText: 'Anfragertyp (Zentralruf)',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final typ in _anfragertypen)
                                  DropdownMenuItem(
                                    value: typ,
                                    child: Text(typ),
                                  ),
                              ],
                            ),
                            _field(
                              'name',
                              'Name der Kanzlei',
                              validationMessages: {
                                ValidationMessage.required: (_) =>
                                'Der Name ist ein Pflichtfeld',
                              },
                            ),
                            _field(
                              'strasseHausnummer',
                              'Straße und Hausnummer',
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _field('postleitzahl', 'PLZ'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(flex: 5, child: _field('ort', 'Ort')),
                              ],
                            ),
                            _field(
                              'emailAdresse',
                              'E-Mail-Adresse',
                              keyboardType: TextInputType.emailAddress,
                              validationMessages: {
                                ValidationMessage.email: (_) =>
                                'Bitte eine gültige E-Mail-Adresse eingeben',
                              },
                            ),
                            _field(
                              'telefonnummer',
                              'Telefonnummer',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                        FormSection(
                          icon: Icons.tag,
                          title: 'Referenz / Auftragsnummer',
                          subtitle:
                          'Die laufende Auftragsnummer und die Abteilung '
                              'bilden die Referenz (Nr/Jahr Abteilung_Kennzeichen). '
                              'Die Auftragsnummer wird in der Zentralruf-Anfrage '
                              'automatisch vorbelegt und beim Abschluss eines '
                              'Vorgangs um eins hochgezählt.',
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _field(
                                    'laufendeAuftragsnummer',
                                    'Laufende Auftragsnummer',
                                    keyboardType: TextInputType.number,
                                    validationMessages: {
                                      ValidationMessage.required: (_) =>
                                      'Pflichtfeld',
                                      ValidationMessage.number: (_) =>
                                      'Bitte eine Zahl eingeben',
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _field(
                                    'abteilung',
                                    'Abteilung (z. B. C03)',
                                    validationMessages: {
                                      ValidationMessage.required: (_) =>
                                      'Pflichtfeld',
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        FormSection(
                          icon: Icons.table_chart,
                          title: 'Schadensaufstellung (Word-Dokumente)',
                          subtitle:
                          'Farbe der Titelzeile der Schadensaufstellungs-Tabelle. '
                              'Die Zebra-Streifen der Positionszeilen werden daraus '
                              'abgeleitet.',
                          children: const [_TabellenkopfFarbeField()],
                        ),
                        FormSection(
                          icon: Icons.folder_special,
                          title: 'Aktensystem',
                          subtitle:
                          'Stammordner, unter dem pro Mandant eine Akte '
                              '(Unterordner) liegt. Die fertigen Dokumente '
                              'werden hier automatisch abgelegt. Ohne '
                              'Stammordner ist nur das manuelle Speichern '
                              'möglich.',
                          children: const [_StammordnerField()],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ReactiveFormConsumer(
                            builder: (context, form, child) {
                              return FilledButton.icon(
                                icon: isSaving
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Icon(Icons.save),
                                label: const Text('Speichern'),
                                onPressed: (form.valid && !isSaving)
                                    ? _save
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(String controlName,
      String label, {
        TextInputType? keyboardType,
        Map<String, String Function(Object)>? validationMessages,
      }) {
    return ReactiveTextField<String>(
      formControlName: controlName,
      keyboardType: keyboardType,
      validationMessages: validationMessages,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Auswahl des Akten-Stammordners: schreibgeschütztes Pfadfeld plus ein
/// Button, der den nativen Ordner-Auswahldialog öffnet. Der Pfad wird nicht
/// frei getippt, damit kein ungültiger/nicht existierender Ordner gespeichert
/// wird.
class _StammordnerField extends StatelessWidget {
  const _StammordnerField();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: 'aktenStammordner',
      builder: (context, control, _) {
        final pfad = (control.value ?? '').trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: pfad),
                    decoration: InputDecoration(
                      labelText: 'Stammordner des Aktensystems',
                      hintText: 'Noch kein Ordner gewählt',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder_outlined),
                      suffixIcon: pfad.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Stammordner entfernen',
                        onPressed: () => control.value = '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await FilePicker.platform
                        .getDirectoryPath(
                      dialogTitle: 'Stammordner des Aktensystems wählen',
                    );
                    if (selected != null) control.value = selected;
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ordner wählen'),
                ),
              ],
            ),
            if (pfad.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ohne Stammordner kann die App fertige Dokumente nicht '
                    'automatisch in die Akte ablegen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Auswahl der Titelzeilen-Farbe der Schadensaufstellung: vordefinierte
/// Farbfelder plus freie Hex-Eingabe mit Live-Vorschau.
class _TabellenkopfFarbeField extends StatelessWidget {
  const _TabellenkopfFarbeField();

  static const List<(String, String)> _vorschlaege = [
    ('D9D9D9', 'Grau (Standard)'),
    ('B4C6E7', 'Blau'),
    ('C6E0B4', 'Grün'),
    ('FFE699', 'Gelb'),
    ('F8CBAD', 'Orange'),
  ];

  static Color? _parse(String? hex) {
    final value = hex?.trim().replaceFirst('#', '') ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: 'tabellenkopfFarbeHex',
      builder: (context, control, _) {
        final current = (control.value ?? '')
            .replaceFirst('#', '')
            .toUpperCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (hex, label) in _vorschlaege)
                  Tooltip(
                    message: label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => control.value = hex,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parse(hex),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: current == hex
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            width: current == hex ? 3 : 1,
                          ),
                        ),
                        child: current == hex
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ReactiveTextField<String>(
              formControlName: 'tabellenkopfFarbeHex',
              validationMessages: {
                ValidationMessage.required: (_) =>
                'Bitte einen Hex-Farbwert angeben (z. B. D9D9D9)',
                ValidationMessage.pattern: (_) =>
                'Ungültiger Farbwert — erwartet wird "RRGGBB" (z. B. D9D9D9)',
              },
              decoration: InputDecoration(
                labelText: 'Farbe als Hex-Wert (RRGGBB)',
                border: const OutlineInputBorder(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: _parse(control.value) ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
