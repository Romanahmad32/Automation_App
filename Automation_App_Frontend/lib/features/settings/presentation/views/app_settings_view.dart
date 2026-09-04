import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
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

  // Der `TraegeIndexedStack` der Einstellungsseite hält diese Ansicht schon
  // von sich aus am Leben. KeepAlive bleibt trotzdem stehen: Es kostet nichts
  // und hält die Ansicht auch dann heil, wenn sie wieder in einer
  // `TabBarView` oder einer Liste landet — dort verwürfe der Wechsel den
  // State, der Bloc stünde schon auf „Loaded", der Listener feuerte nicht
  // erneut, und die Kanzleidaten wären weg (und würden beim Speichern mit
  // Vorgabewerten überschrieben).
  @override
  bool get wantKeepAlive => true;

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
    // Die Titelzeilen-Farbe der Schadensaufstellung liegt im Reiter
    // "Schadensaufstellung" (StandardpositionenSettingsView) und speichert
    // dort für sich (SaveTabellenkopfFarbeEvent).
    'aktenStammordner': FormControl<String>(),
    // Vorlagenordner (#33), ohne Validator: Leer heißt App-Ordner des
    // Backends unter %APPDATA% — der Stand vor dieser Einstellung.
    'vorlagenOrdner': FormControl<String>(),
    // Register-Spiegel (§6.2). Der Ablageordner ist bewusst ohne Validator:
    // Er darf leer bleiben — dann wird keine Datei geschrieben.
    'registerAblageOrdner': FormControl<String>(),
    'registerDateiname': FormControl<String>(
      value: KanzleiSettings.defaultRegisterDateiname,
    ),
    'registerNachAbschlussSchreiben': FormControl<bool>(value: true),
    'registerExportFilter': FormControl<String>(
      value: KanzleiSettings.registerFilterAlle,
    ),
    // Sicherungsablage (§7.2, #39), ebenfalls ohne Validator: Leer heißt keine
    // automatische Sicherung — der Ordner schaltet die Funktion ein.
    'sicherungsAblageOrdner': FormControl<String>(),
  });

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
      'aktenStammordner': settings.aktenStammordner,
      'vorlagenOrdner': settings.vorlagenOrdner,
      'registerAblageOrdner': settings.registerAblageOrdner,
      'registerDateiname': settings.registerDateiname,
      'registerNachAbschlussSchreiben': settings.registerNachAbschlussSchreiben,
      'registerExportFilter': settings.registerExportFilter,
      'sicherungsAblageOrdner': settings.sicherungsAblageOrdner,
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
          // Kürzel ohne Leerzeichen (§7.1): 'C 03o' zerlegte die Referenz
          // auf beiden Seiten still.
          abteilung: AbteilungKuerzel.normalisiere(read('abteilung')),
          aktenStammordner: read('aktenStammordner'),
          vorlagenOrdner: read('vorlagenOrdner'),
          registerAblageOrdner: read('registerAblageOrdner'),
          // Leerer Name heißt Vorgabe: Ein Spiegel ohne Dateinamen wäre eine
          // Datei, die nur ".docx" heißt.
          registerDateiname: read('registerDateiname').isEmpty
              ? KanzleiSettings.defaultRegisterDateiname
              : read('registerDateiname'),
          registerNachAbschlussSchreiben:
              (value['registerNachAbschlussSchreiben'] as bool?) ?? true,
          registerExportFilter: read('registerExportFilter').isEmpty
              ? KanzleiSettings.registerFilterAlle
              : read('registerExportFilter'),
          sicherungsAblageOrdner: read('sicherungsAblageOrdner'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return StandNachziehen<KanzleiSettingsBloc, KanzleiSettingsState>(
      // Auch der Stand, der beim Aufgehen schon dasteht — sonst bliebe das
      // Formular leer, wenn der Bloc vor dem ersten Aufbau fertig war, und
      // „Speichern" schriebe die Vorgabewerte über die Kanzleidaten.
      nachziehen: (context, state) {
        if (state is! KanzleiSettingsLoaded || _initialized) return;
        _patch(state.settings);
        _initialized = true;
      },
      beiUebergang: (context, state) {
        if (state is KanzleiSettingsLoaded) {
          if (state.gespeichert == KanzleiSettingsBereich.kanzlei) {
            Rueckmeldung.zeigeErfolg(context, 'Kanzleidaten gespeichert');
          }
        } else if (state is KanzleiSettingsError) {
          Rueckmeldung.zeigeFehler(context, state.message);
        }
      },
      builder: (context, state) {
        if (!_initialized && state is KanzleiSettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaving = state is KanzleiSettingsLoading;

        // Der ReactiveForm liegt über dem ganzen Reiter, nicht nur über den
        // Feldern: Der Speichern-Knopf steht in dessen Kopfzeile und liest
        // über den Context, ob das Formular gültig ist.
        return ReactiveForm(
          formGroup: _form,
          child: KanzleiSettingsFormBody(isSaving: isSaving, onSave: _save),
        );
      },
    );
  }
}
