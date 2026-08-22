import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandant_edit_cubit/mandant_edit_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/kennzeichen_editor.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/ordner_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

@RoutePage()
class MandantDetailsPage extends StatefulWidget implements AutoRouteWrapper {
  /// Zu bearbeitender Mandant; null = neuer Mandant.
  final Mandant? mandant;

  /// Optional: Ordner, der beim Anlegen direkt zugeordnet wird (aus der
  /// manuellen Zuordnung eines gefundenen Ordners).
  final String? vorbelegterOrdner;
  final String? vorbelegterVorname;
  final String? vorbelegterNachname;

  const MandantDetailsPage({
    super.key,
    this.mandant,
    this.vorbelegterOrdner,
    this.vorbelegterVorname,
    this.vorbelegterNachname,
  });

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<MandantEditCubit>(),
      child: this,
    );
  }

  @override
  State<MandantDetailsPage> createState() => _MandantDetailsPageState();
}

class _MandantDetailsPageState extends State<MandantDetailsPage> {
  late final bool _istBearbeitung = widget.mandant != null;

  late List<String> _kennzeichen = List.of(
    widget.mandant?.kennzeichen ?? const [],
  );

  late Anrede _anrede = widget.mandant?.anrede ?? Anrede.keine;

  late final FormGroup _form = FormGroup({
    'vorname': FormControl<String>(
      value: widget.mandant?.vorname ?? widget.vorbelegterVorname ?? '',
    ),
    'nachname': FormControl<String>(
      value: widget.mandant?.nachname ?? widget.vorbelegterNachname ?? '',
      validators: [Validators.required],
    ),
    'strasseHausnummer': FormControl<String>(
      value: widget.mandant?.strasseHausnummer ?? '',
    ),
    'postleitzahl': FormControl<String>(
      value: widget.mandant?.postleitzahl ?? '',
    ),
    'ort': FormControl<String>(value: widget.mandant?.ort ?? ''),
    'emailAdresse': FormControl<String>(
      value: widget.mandant?.emailAdresse ?? '',
      validators: [Validators.email],
    ),
    'telefonnummer': FormControl<String>(
      value: widget.mandant?.telefonnummer ?? '',
    ),
    'notiz': FormControl<String>(value: widget.mandant?.notiz ?? ''),
  });

  void _speichern() {
    final value = _form.value;
    String read(String key) => (value[key] as String?)?.trim() ?? '';

    final cubit = context.read<MandantEditCubit>();
    if (_istBearbeitung) {
      cubit.aktualisiere(
        widget.mandant!.copyWith(
          anrede: _anrede,
          vorname: read('vorname'),
          nachname: read('nachname'),
          strasseHausnummer: read('strasseHausnummer'),
          postleitzahl: read('postleitzahl'),
          ort: read('ort'),
          emailAdresse: read('emailAdresse'),
          telefonnummer: read('telefonnummer'),
          notiz: read('notiz'),
          kennzeichen: _kennzeichen,
        ),
      );
    } else {
      cubit.erstelle(
        CreateMandantRequest(
          anrede: _anrede,
          vorname: read('vorname'),
          nachname: read('nachname'),
          strasseHausnummer: read('strasseHausnummer'),
          postleitzahl: read('postleitzahl'),
          ort: read('ort'),
          emailAdresse: read('emailAdresse'),
          telefonnummer: read('telefonnummer'),
          notiz: read('notiz'),
          kennzeichen: _kennzeichen,
          aktenOrdnernamen: widget.vorbelegterOrdner == null
              ? const []
              : [widget.vorbelegterOrdner!],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MandantEditCubit, MandantEditState>(
      listener: (context, state) {
        if (state.status == MandantEditStatus.success) {
          context.router.maybePop(true);
        } else if (state.status == MandantEditStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? 'Speichern fehlgeschlagen'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: SeitenAppBar(
          titel: _istBearbeitung ? 'Mandant bearbeiten' : 'Neuer Mandant',
          icon: _istBearbeitung ? Icons.edit_outlined : Icons.person_add_alt,
          untertitel: 'Stammdaten des Mandanten',
        ),
        body: Scrollbar(
          child: SingleChildScrollView(
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
                        if (widget.vorbelegterOrdner != null)
                          OrdnerHinweis(ordnername: widget.vorbelegterOrdner!),
                        FormSection(
                          icon: Icons.person,
                          title: 'Mandantendaten',
                          subtitle:
                              'Diese Daten werden gespeichert und können bei '
                              'künftigen Vorgängen wiederverwendet werden. '
                              'Pflichtfelder sind mit * markiert.',
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Anrede',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            AnredeAuswahl(
                              initialAnrede: _anrede,
                              onChanged: (wert) => _anrede = wert,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _field('vorname', 'Vorname')),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    'nachname',
                                    'Nachname *',
                                    validationMessages: {
                                      ValidationMessage.required: (_) =>
                                          'Der Nachname ist ein Pflichtfeld',
                                    },
                                  ),
                                ),
                              ],
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
                            _field('notiz', 'Notiz', maxLines: 3),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Kennzeichen (optional)',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            KennzeichenEditor(
                              initialKennzeichen: _kennzeichen,
                              onChanged: (werte) => _kennzeichen = werte,
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child:
                              BlocBuilder<MandantEditCubit, MandantEditState>(
                                builder: (context, state) {
                                  final isSaving =
                                      state.status == MandantEditStatus.saving;
                                  return ReactiveFormConsumer(
                                    builder: (context, form, child) {
                                      return FilledButton.icon(
                                        icon: isSaving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.save),
                                        label: const Text('Speichern'),
                                        onPressed: (form.valid && !isSaving)
                                            ? _speichern
                                            : null,
                                      );
                                    },
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
        ),
      ),
    );
  }

  Widget _field(
    String controlName,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    Map<String, String Function(Object)>? validationMessages,
  }) {
    return GeneralTextField<String>(
      formControlName: controlName,
      labelText: label,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validationMessages: validationMessages,
    );
  }
}
