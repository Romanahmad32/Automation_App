import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/kanzlei_settings_form_body.dart';
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

    final bloc = context.read<KanzleiSettingsBloc>();
    final stand = bloc.state;

    // Auf dem gespeicherten Stand aufsetzen und nur überschreiben, was dieses
    // Formular besitzt. Die Signatur etwa steht im E-Mail-Reiter; würde hier
    // ein frischer Satz gebaut, löschte jedes Speichern der Kanzleidaten sie
    // still mit — und dasselbe gälte für jedes künftige Feld daneben.
    final basis = stand is KanzleiSettingsLoaded
        ? stand.settings
        : KanzleiSettings.empty;

    bloc.add(
      SaveKanzleiSettingsEvent(
        basis.copyWith(
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
          if (state.gespeichert == KanzleiSettingsBereich.kanzlei) {
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
                    child: KanzleiSettingsFormBody(
                      isSaving: isSaving,
                      onSave: _save,
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
}
