import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/zentralruf_request/presentation/blocs/zentralruf_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

class ZentralrufFormView extends StatefulWidget {
  const ZentralrufFormView({super.key});

  @override
  State<ZentralrufFormView> createState() => _ZentralrufFormViewState();
}

class _ZentralrufFormViewState extends State<ZentralrufFormView> {
  // Kennzeichen werden mit Bindestrich angegeben, z. B. "HG-E 1427"
  // (optional E/H-Suffix für Elektro-/Oldtimer-Kennzeichen).
  static final _kennzeichenRegExp = RegExp(
    r'^[A-ZÄÖÜ]{1,3}-[A-Z]{1,2}\s?\d{1,4}\s?[EH]?$',
    caseSensitive: false,
  );

  static const _kennzeichenHinweis = 'Mit Bindestrich angeben, z. B. HG-E 1427';

  /// Prüft das Kennzeichen-Format, lässt leere Werte aber zu
  /// (Pflicht regelt der Required-Validator des jeweiligen Feldes).
  static Map<String, dynamic>? _kennzeichenValidator(
    AbstractControl<dynamic> control,
  ) {
    final value = (control.value as String?)?.trim() ?? '';
    if (value.isEmpty || _kennzeichenRegExp.hasMatch(value)) {
      return null;
    }
    return {ValidationMessage.pattern: true};
  }

  static final _kennzeichenMessages = {
    ValidationMessage.pattern: (Object _) => _kennzeichenHinweis,
  };

  // Unfalluhrzeit im 24-Stunden-Format, z. B. "14:05" (Stunde ein- oder zweistellig).
  static final _uhrzeitRegExp = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');

  static const _uhrzeitHinweis = 'Im Format HH:MM angeben, z. B. 14:05';

  // Polizeiliche Vorgangsnummer, z. B. "VU/1234567/2026"
  // (Kürzel/Ziffernfolge/vierstelliges Jahr).
  static final _vorgangsnummerRegExp = RegExp(
    r'^[A-ZÄÖÜ]{1,5}/\d{1,9}/\d{4}$',
    caseSensitive: false,
  );

  static const _vorgangsnummerHinweis = 'Format: VU/1234567/2026';

  /// Prüft das Uhrzeit-Format, lässt leere Werte aber zu (Feld ist optional).
  static Map<String, dynamic>? _uhrzeitValidator(
    AbstractControl<dynamic> control,
  ) {
    final value = (control.value as String?)?.trim() ?? '';
    if (value.isEmpty || _uhrzeitRegExp.hasMatch(value)) {
      return null;
    }
    return {ValidationMessage.pattern: true};
  }

  static final _uhrzeitMessages = {
    ValidationMessage.pattern: (Object _) => _uhrzeitHinweis,
  };

  /// Prüft die Vorgangsnummer, lässt leere Werte aber zu (Feld ist optional).
  static Map<String, dynamic>? _vorgangsnummerValidator(
    AbstractControl<dynamic> control,
  ) {
    final value = (control.value as String?)?.trim() ?? '';
    if (value.isEmpty || _vorgangsnummerRegExp.hasMatch(value)) {
      return null;
    }
    return {ValidationMessage.pattern: true};
  }

  static final _vorgangsnummerMessages = {
    ValidationMessage.pattern: (Object _) => _vorgangsnummerHinweis,
  };

  bool _withGeschaedigter = false;

  /// Rechtsgebiet des Vorgangs (Sachgebiete-Spalte des Auftragsregisters).
  /// Verkehrsrecht ist der Schwerpunkt der Kanzlei und damit vorbelegt.
  Rechtsgebiet _rechtsgebiet = Rechtsgebiet.verkehrsrecht;

  /// Im Register hinterlegte Mandanten zum Vorbefüllen des Geschädigten
  /// (Daten wiederverwenden statt neu tippen).
  List<Mandant> _mandanten = const [];

  /// Aus dem Register gewählter Mandant — Verknüpfung des Vorgangs. Wird beim
  /// Absenden nur übernommen, solange der Name unverändert geblieben ist.
  int? _selectedMandantId;
  String? _selectedMandantName;

  /// True, sobald der Anwender die Referenz selbst bearbeitet hat. Danach wird
  /// die Vorschau nicht mehr automatisch aus den Feldern überschrieben.
  bool _referenzManuallyEdited = false;

  /// Quellfelder, aus denen die Referenz zusammengebaut wird.
  static const _referenzQuellfelder = [
    'auftragsnummer',
    'auftragsjahr',
    'abteilung',
    'kennzeichenSchaediger',
  ];

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late final FormGroup _form = FormGroup({
    'auftragsnummer': FormControl<String>(
      validators: [Validators.required, Validators.number()],
    ),
    // Standardmäßig das aktuelle zweistellige Jahr (z. B. "26"); bleibt
    // bearbeitbar.
    'auftragsjahr': FormControl<String>(
      value: (DateTime.now().year % 100).toString().padLeft(2, '0'),
    ),
    // Häufigste Abteilung als Vorbelegung; bleibt änderbar.
    'abteilung': FormControl<String>(
      value: 'C03',
      validators: [Validators.required],
    ),
    'kennzeichenSchaediger': FormControl<String>(
      validators: [
        Validators.required,
        Validators.delegate(_kennzeichenValidator),
      ],
    ),
    'schadentag': FormControl<String>(
      validators: [
        Validators.required,
        // Ein Unfalltag kann nicht in der Zukunft liegen.
        GermanDateField.validator(
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        ),
      ],
    ),
    'geschaedigterName': FormControl<String>(),
    'geschaedigterStrasseHausnummer': FormControl<String>(),
    'geschaedigterPostleitzahl': FormControl<String>(),
    'geschaedigterOrt': FormControl<String>(),
    'geschaedigterKennzeichen': FormControl<String>(
      validators: [Validators.delegate(_kennzeichenValidator)],
    ),
    // Unfallhergang (optional) — Straße und Ort, Uhrzeit, polizeiliche Vorgangsnummer.
    'unfallort': FormControl<String>(),
    'unfalluhrzeit': FormControl<String>(
      validators: [Validators.delegate(_uhrzeitValidator)],
    ),
    'polizeiVorgangsnummer': FormControl<String>(
      validators: [Validators.delegate(_vorgangsnummerValidator)],
    ),
    // Vorschau der resultierenden Referenz; wird automatisch befüllt, bis der
    // Anwender sie selbst bearbeitet (siehe [_referenzManuallyEdited]).
    'referenz': FormControl<String>(),
  });

  @override
  void initState() {
    super.initState();

    // Quellfeld-Änderungen spiegeln sich in der Vorschau wider, solange der
    // Anwender die Referenz nicht selbst überschrieben hat.
    for (final name in _referenzQuellfelder) {
      _subscriptions.add(
        _form.control(name).valueChanges.listen((_) => _syncReferenzVorschau()),
      );
    }

    // Manuelle Bearbeitung erkennen: weicht der Feldwert von der automatisch
    // erzeugten Referenz ab, hat der Anwender selbst getippt. (Ein Vergleich
    // statt Event-Unterdrückung, damit das Textfeld die Vorschau weiter anzeigt.)
    _subscriptions.add(
      _form.control('referenz').valueChanges.listen((value) {
        if (_referenzManuallyEdited) return;
        final current = (value as String?)?.trim() ?? '';
        if (current != _buildReferenz()) {
          setState(() => _referenzManuallyEdited = true);
        }
      }),
    );

    _syncReferenzVorschau();

    // Mandantenregister laden, damit der Geschädigte daraus vorbefüllt werden
    // kann (best-effort; ohne Register bleibt nur die manuelle Eingabe).
    unawaited(_ladeMandanten());

    // Falls die Vorbelegung (Auftragsnummer/Abteilung) schon geladen ist, bevor
    // der BlocListener greift, den aktuellen Stand einmalig übernehmen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<ZentralrufBloc>().state;
      if (state is ZentralrufDefaultsLoaded) {
        _patchDefaults(state.auftragsnummer, state.abteilung);
      }
    });
  }

  /// Übernimmt die laufende Auftragsnummer und Abteilung aus den Einstellungen
  /// in die Formularfelder. updateValue lässt die Referenz-Vorschau mitlaufen.
  void _patchDefaults(int auftragsnummer, String abteilung) {
    _form.control('auftragsnummer').updateValue(auftragsnummer.toString());
    if (abteilung.trim().isNotEmpty) {
      _form.control('abteilung').updateValue(abteilung);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _form.dispose();
    super.dispose();
  }

  /// Baut die Referenz nach demselben Schema wie das Backend zusammen:
  /// `Nr/Jahr Abteilung_Kennzeichen` (siehe ZentralrufAutomationService.BuildReferenz).
  String _buildReferenz() {
    String valueOf(String controlName) =>
        (_form.control(controlName).value as String?)?.trim() ?? '';

    final nummer = valueOf('auftragsnummer');
    final jahrEingabe = int.tryParse(valueOf('auftragsjahr')) ?? 0;
    final jahr = jahrEingabe == 0 ? DateTime.now().year % 100 : jahrEingabe;
    final abteilung = valueOf('abteilung');
    final kennzeichen = valueOf('kennzeichenSchaediger').toUpperCase();

    return '$nummer/${jahr.toString().padLeft(2, '0')} ${abteilung}_$kennzeichen';
  }

  /// Aktualisiert die Vorschau aus den Quellfeldern. Das valueChanges-Event wird
  /// bewusst ausgelöst, damit das Textfeld den neuen Wert anzeigt; die
  /// Manuell-Erkennung filtert es per Wertvergleich wieder heraus.
  void _syncReferenzVorschau() {
    if (_referenzManuallyEdited) return;
    _form.control('referenz').updateValue(_buildReferenz());
  }

  /// Verwirft die manuelle Bearbeitung und erzeugt die Referenz wieder automatisch.
  void _resetReferenz() {
    setState(() => _referenzManuallyEdited = false);
    _syncReferenzVorschau();
  }

  /// Lädt die Mandanten aus dem lokalen Register (für die Vorbefüllung).
  Future<void> _ladeMandanten() async {
    final result = await getIt<UseCase<List<Mandant>, NoParams>>().call(
      const NoParams(),
    );
    if (!mounted) return;
    switch (result) {
      case Right(value: final mandanten):
        setState(() => _mandanten = mandanten);
      case Left():
        break;
    }
  }

  /// Übernimmt die Stammdaten des gewählten Mandanten in die Geschädigten-Felder
  /// und merkt sich die Verknüpfung. Schaltet den Geschädigten-Abschnitt ein.
  void _uebernehmeMandant(Mandant mandant) {
    _form.control('geschaedigterName').updateValue(mandant.anzeigename);
    _form
        .control('geschaedigterStrasseHausnummer')
        .updateValue(mandant.strasseHausnummer);
    _form.control('geschaedigterPostleitzahl').updateValue(mandant.postleitzahl);
    _form.control('geschaedigterOrt').updateValue(mandant.ort);
    setState(() {
      _withGeschaedigter = true;
      _selectedMandantId = mandant.id;
      _selectedMandantName = mandant.anzeigename;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ZentralrufBloc, ZentralrufState>(
      listener: (context, state) {
        // Erstbefüllung aus den Einstellungen. Eine erhöhte Auftragsnummer wird
        // bewusst NICHT sofort ins Feld gespiegelt (der Anwalt bearbeitet ggf.
        // noch den laufenden Vorgang); der neue Wert erscheint beim nächsten
        // Öffnen der Anfrage über diesen Pfad.
        if (state is ZentralrufDefaultsLoaded) {
          _patchDefaults(state.auftragsnummer, state.abteilung);
        }
      },
      child: ReactiveForm(
        formGroup: _form,
        // Die gesamte Seite scrollt (volle Breite, Scrollbar am Seitenrand);
        // der Formularinhalt bleibt darin zentriert und breitenbegrenzt.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  // Auftrag und Unfall nebeneinander, damit die Seitenbreite auf
                  // großen Fenstern genutzt wird (gleiche Kartenhöhe via
                  // IntrinsicHeight + stretch).
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FormSection(
                            icon: Icons.assignment_outlined,
                            title: 'Auftrag',
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Expanded(
                                    flex: 3,
                                    child: GeneralTextField<String>(
                                      labelText: 'Auftragsnummer',
                                      formControlName: 'auftragsnummer',
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: GeneralTextField<String>(
                                      labelText: 'Jahr',
                                      formControlName: 'auftragsjahr',
                                    ),
                                  ),
                                ],
                              ),
                              const GeneralTextField<String>(
                                labelText: 'Abteilung (z. B. C03)',
                                formControlName: 'abteilung',
                              ),
                              DropdownButtonFormField<Rechtsgebiet>(
                                initialValue: _rechtsgebiet,
                                decoration: const InputDecoration(
                                  labelText: 'Rechtsgebiet',
                                ),
                                items: [
                                  for (final gebiet in Rechtsgebiet.values)
                                    DropdownMenuItem(
                                      value: gebiet,
                                      child: Text(gebiet.displayName),
                                    ),
                                ],
                                onChanged: (gebiet) => setState(
                                  () => _rechtsgebiet =
                                      gebiet ?? Rechtsgebiet.verkehrsrecht,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FormSection(
                            icon: Icons.directions_car_outlined,
                            title: 'Unfall',
                            children: [
                              GeneralTextField<String>(
                                labelText:
                                    'Kennzeichen des Unfallgegners (z. B. HG-E 1427)',
                                formControlName: 'kennzeichenSchaediger',
                                validationMessages: _kennzeichenMessages,
                              ),
                              // Direkt tippbar; das Kalender-Icon öffnet den Dialog.
                              GermanDateField(
                                formControlName: 'schadentag',
                                labelText: 'Unfalldatum',
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                validationMessages: {
                                  GermanDateField.rangeError: (_) =>
                                      'Der Unfalltag kann nicht in der Zukunft liegen',
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  FormSection(
                    icon: Icons.bookmark_outline,
                    title: 'Referenz',
                    children: [
                      GeneralTextField<String>(
                        labelText: 'Referenz (Vorschau, bearbeitbar)',
                        formControlName: 'referenz',
                        inputDecoration: InputDecoration(
                          helperText: _referenzManuallyEdited
                              ? 'Manuell bearbeitet – wird so an das Formular übergeben.'
                              : 'Wird automatisch aus den Feldern oben erzeugt.',
                          helperMaxLines: 2,
                          suffixIcon: _referenzManuallyEdited
                              ? IconButton(
                                  icon: const Icon(Icons.restart_alt),
                                  tooltip:
                                      'Automatisch aus den Feldern erzeugen',
                                  onPressed: _resetReferenz,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  FormSection(
                    icon: Icons.person_outline,
                    title: 'Geschädigter',
                    subtitle:
                        'Optional — nur ausfüllen, wenn die Daten dem '
                        'Zentralruf-Formular mitgegeben werden sollen.',
                    trailing: Switch(
                      value: _withGeschaedigter,
                      onChanged: (value) =>
                          setState(() => _withGeschaedigter = value),
                    ),
                    children: [
                      if (_withGeschaedigter) ...[
                        if (_mandanten.isNotEmpty)
                          DropdownButtonFormField<int>(
                            initialValue: _selectedMandantId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Aus Mandanten übernehmen',
                              helperText:
                                  'Füllt die Felder aus dem Register; '
                                  'Änderungen am Namen lösen die Verknüpfung.',
                              helperMaxLines: 2,
                            ),
                            items: [
                              for (final mandant in _mandanten)
                                DropdownMenuItem(
                                  value: mandant.id,
                                  child: Text(mandant.anzeigename),
                                ),
                            ],
                            onChanged: (id) {
                              if (id == null) return;
                              final mandant = _mandanten.firstWhere(
                                (m) => m.id == id,
                              );
                              _uebernehmeMandant(mandant);
                            },
                          ),
                        const GeneralTextField<String>(
                          labelText: 'Name des Geschädigten',
                          formControlName: 'geschaedigterName',
                        ),
                        const GeneralTextField<String>(
                          labelText: 'Straße und Hausnummer',
                          formControlName: 'geschaedigterStrasseHausnummer',
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Expanded(
                              flex: 2,
                              child: GeneralTextField<String>(
                                labelText: 'PLZ',
                                formControlName: 'geschaedigterPostleitzahl',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: GeneralTextField<String>(
                                labelText: 'Ort',
                                formControlName: 'geschaedigterOrt',
                              ),
                            ),
                          ],
                        ),
                        GeneralTextField<String>(
                          labelText:
                              'Kennzeichen des Geschädigten (z. B. HG-E 1427)',
                          formControlName: 'geschaedigterKennzeichen',
                          validationMessages: _kennzeichenMessages,
                        ),
                      ],
                    ],
                  ),
                  FormSection(
                    icon: Icons.car_crash_outlined,
                    title: 'Unfallhergang',
                    subtitle:
                        'Optional — Angaben zum Unfall für die spätere '
                        'Akten- und Schreibenerstellung.',
                    children: [
                      const GeneralTextField<String>(
                        labelText:
                            'Unfallort (Straße und Ort, z. B. Am Ulmenrück, '
                            'Frankfurt am Main)',
                        formControlName: 'unfallort',
                      ),
                      GeneralTextField<String>(
                        labelText: 'Unfalluhrzeit (z. B. 14:05)',
                        formControlName: 'unfalluhrzeit',
                        validationMessages: _uhrzeitMessages,
                      ),
                      GeneralTextField<String>(
                        labelText:
                            'Polizeiliche Vorgangsnummer (z. B. VU/1234567/2026)',
                        formControlName: 'polizeiVorgangsnummer',
                        validationMessages: _vorgangsnummerMessages,
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: BlocBuilder<ZentralrufBloc, ZentralrufState>(
                      builder: (context, state) {
                        final isLoading = state is ZentralrufLoading;
                        return ReactiveFormConsumer(
                          builder: (context, formGroup, child) {
                            return FilledButton.icon(
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.open_in_browser),
                              label: const Text('Anfrageformular ausfüllen'),
                              onPressed: (formGroup.valid && !isLoading)
                                  ? _submit
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
    );
  }

  void _submit() {
    String valueOf(String controlName) =>
        (_form.control(controlName).value as String?)?.trim() ?? '';

    // Vom Validator bereits geprüft — Parsen kann hier nicht fehlschlagen.
    final schadentag = GermanDateField.parseDate(valueOf('schadentag'))!;

    final request = ZentralrufRequest(
      auftragsnummer: int.parse(valueOf('auftragsnummer')),
      auftragsjahr: int.tryParse(valueOf('auftragsjahr')) ?? 0,
      abteilung: valueOf('abteilung'),
      // Kennzeichen normalisiert in Großbuchstaben übergeben (HG-E 1427).
      kennzeichenSchaediger: valueOf('kennzeichenSchaediger').toUpperCase(),
      schadentag: schadentag,
      // Die in der Vorschau angezeigte (ggf. bearbeitete) Referenz wird 1:1
      // übergeben; ist sie leer, baut das Backend sie aus den Feldern zusammen.
      referenz: valueOf('referenz').isEmpty ? null : valueOf('referenz'),
      geschaedigter:
          _withGeschaedigter && valueOf('geschaedigterName').isNotEmpty
          ? ZentralrufGeschaedigter(
              name: valueOf('geschaedigterName'),
              strasseHausnummer: valueOf('geschaedigterStrasseHausnummer'),
              postleitzahl: valueOf('geschaedigterPostleitzahl'),
              ort: valueOf('geschaedigterOrt'),
              kennzeichen: valueOf('geschaedigterKennzeichen').toUpperCase(),
            )
          : null,
    );

    // Verknüpfung nur halten, solange der Name dem gewählten Mandanten
    // entspricht (sonst hat der Anwalt den Geschädigten ausgetauscht). Der Name
    // wird als Schnappschuss auch ohne Registereintrag mitgegeben, damit der
    // Vorgang „Name ./. Gegner" anzeigen und ins Register schreiben kann.
    final geschaedigterName = valueOf('geschaedigterName');
    final verknuepft =
        _selectedMandantId != null &&
        geschaedigterName == (_selectedMandantName?.trim() ?? '');

    context.read<ZentralrufBloc>().add(
      PrefillZentralrufFormEvent(
        request: request,
        rechtsgebiet: _rechtsgebiet,
        mandantId: verknuepft ? _selectedMandantId : null,
        mandantName: geschaedigterName.isEmpty ? null : geschaedigterName,
      ),
    );
  }
}
