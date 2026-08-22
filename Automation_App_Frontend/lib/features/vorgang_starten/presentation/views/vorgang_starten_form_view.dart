import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_uebersicht_dialog.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_aktionsleiste.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_reader.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_starten_sektionen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

class VorgangStartenFormView extends StatefulWidget {
  const VorgangStartenFormView({super.key});

  @override
  State<VorgangStartenFormView> createState() => _VorgangStartenFormViewState();
}

class _VorgangStartenFormViewState extends State<VorgangStartenFormView> {
  Rechtsgebiet _rechtsgebiet = Rechtsgebiet.verkehrsrecht;

  List<Mandant> _mandanten = const [];
  int? _selectedMandantId;

  bool _referenzManuallyEdited = false;

  static const _referenzQuellfelder = [
    'auftragsnummer',
    'auftragsjahr',
    'abteilung',
    'kennzeichenGegner',
  ];

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final FormGroup _form = createVorgangForm();

  bool get _istVerkehrsunfall => _rechtsgebiet == Rechtsgebiet.verkehrsrecht;

  @override
  void initState() {
    super.initState();
    _applyUnfallValidators();

    for (final name in _referenzQuellfelder) {
      _subscriptions.add(
        _form.control(name).valueChanges.listen((_) => _syncReferenzVorschau()),
      );
    }
    // Manuelle Bearbeitung erkennen (Wertvergleich statt Event-Unterdrückung).
    _subscriptions.add(
      _form.control('referenz').valueChanges.listen((value) {
        if (_referenzManuallyEdited) return;
        final current = (value as String?)?.trim() ?? '';
        if (current != baueReferenz(_form, _rechtsgebiet)) {
          setState(() => _referenzManuallyEdited = true);
        }
      }),
    );
    _syncReferenzVorschau();
    unawaited(_ladeMandanten());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<VorgangStartenBloc>().state;
      if (state is VorgangStartenDefaultsLoaded) {
        _patchDefaults(state.auftragsnummer, state.abteilung);
      }
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _form.dispose();
    super.dispose();
  }

  void _patchDefaults(int auftragsnummer, String abteilung) {
    _form.control('auftragsnummer').updateValue(auftragsnummer.toString());
    if (abteilung.trim().isNotEmpty) {
      _form.control('abteilung').updateValue(abteilung);
    }
  }

  /// Setzt die Pflicht der Unfall-Felder je nach Rechtsgebiet: Kennzeichen des
  /// Gegners und Unfalltag sind nur bei Verkehrsrecht erforderlich.
  void _applyUnfallValidators() {
    final kennzeichen = _form.control('kennzeichenGegner');
    final schadentag = _form.control('schadentag');
    final dateValidator = GermanDateField.validator(
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (_istVerkehrsunfall) {
      kennzeichen.setValidators([
        Validators.required,
        Validators.delegate(kennzeichenValidator),
      ]);
      schadentag.setValidators([Validators.required, dateValidator]);
    } else {
      kennzeichen.setValidators([Validators.delegate(kennzeichenValidator)]);
      schadentag.setValidators([dateValidator]);
    }
    kennzeichen.updateValueAndValidity();
    schadentag.updateValueAndValidity();
  }

  void _onRechtsgebietChanged(Rechtsgebiet gebiet) {
    setState(() => _rechtsgebiet = gebiet);
    _applyUnfallValidators();
    _syncReferenzVorschau();
  }

  void _syncReferenzVorschau() {
    if (_referenzManuallyEdited) return;
    _form.control('referenz').updateValue(baueReferenz(_form, _rechtsgebiet));
  }

  void _resetReferenz() {
    setState(() => _referenzManuallyEdited = false);
    _syncReferenzVorschau();
  }

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

  Mandant? _findeMandant(int id) {
    for (final mandant in _mandanten) {
      if (mandant.id == id) return mandant;
    }
    return null;
  }

  void _uebernehmeMandant(Mandant mandant) {
    _form.control('mandantVorname').updateValue(mandant.vorname);
    _form.control('mandantNachname').updateValue(mandant.nachname);
    _form.control('mandantStrasse').updateValue(mandant.strasseHausnummer);
    _form.control('mandantPlz').updateValue(mandant.postleitzahl);
    _form.control('mandantOrt').updateValue(mandant.ort);
    _form.control('mandantEmail').updateValue(mandant.emailAdresse);
    _form.control('mandantTelefon').updateValue(mandant.telefonnummer);
    setState(() => _selectedMandantId = mandant.id);
  }

  /// Gemeinsamer Absende-Pfad für „Speichern" und „Zentralruf ausfüllen":
  /// zeigt — wenn am Mandanten etwas neu oder geändert ist — die Übersicht zur
  /// Bestätigung (§1.3) und schickt das Speicher-Event. Abgebrochene Übersicht
  /// bricht das Speichern ab.
  Future<void> _absenden({required bool zentralruf}) async {
    final daten = leseVorgangDaten(_form, _rechtsgebiet);
    final gewaehlt = _selectedMandantId == null
        ? null
        : _findeMandant(_selectedMandantId!);
    final art = mandantAenderungsart(daten, gewaehlt);

    CreateMandantRequest? neuerMandant;
    Mandant? aktualisierterMandant;

    if (art != MandantAenderungsart.keine) {
      final istNeu = art == MandantAenderungsart.neu;
      final bestaetigt = await MandantUebersichtDialog.zeige(
        context,
        istNeu: istNeu,
        zeilen: istNeu
            ? mandantNeuFelder(daten)
            : mandantDiff(daten, gewaehlt!),
      );
      if (bestaetigt != true) return;
      if (istNeu) {
        neuerMandant = daten.toCreateRequest();
      } else {
        aktualisierterMandant = daten.applyTo(gewaehlt!);
      }
    }

    if (!mounted) return;
    context.read<VorgangStartenBloc>().add(
      SpeichereVorgangEvent(
        daten: daten,
        neuerMandant: neuerMandant,
        aktualisierterMandant: aktualisierterMandant,
        verknuepfteMandantId: gewaehlt?.id,
        zentralrufAusfuellen: zentralruf,
      ),
    );
  }

  /// Eigenständiges Speichern des Mandanten über den Karten-Button (Übersicht
  /// wurde dort schon bestätigt). Legt an oder aktualisiert, ohne den Vorgang.
  void _onMandantBestaetigt(
    MandantAenderungsart art,
    VorgangStartenDaten daten,
  ) {
    final gewaehlt = _selectedMandantId == null
        ? null
        : _findeMandant(_selectedMandantId!);
    context.read<VorgangStartenBloc>().add(
      SpeichereMandantEvent(
        neuerMandant: art == MandantAenderungsart.neu
            ? daten.toCreateRequest()
            : null,
        aktualisierterMandant: art == MandantAenderungsart.aktualisierung
            ? daten.applyTo(gewaehlt!)
            : null,
      ),
    );
  }

  /// Übernimmt den gerade gespeicherten Mandanten in die Auswahl: Liste neu laden
  /// (für Kennzeichen-Chips/Dropdown) und Felder verknüpfen.
  Future<void> _uebernehmeGespeicherten(Mandant mandant) async {
    await _ladeMandanten();
    if (!mounted) return;
    _uebernehmeMandant(mandant);
  }

  void _vorlageAusfuellen(String referenz) {
    getIt<VorgangNavigationSignal>().setze(referenz);
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.wordAutomation);
  }

  void _zumPostfach() =>
      AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.postfach);

  @override
  Widget build(BuildContext context) {
    return BlocListener<VorgangStartenBloc, VorgangStartenState>(
      listener: (context, state) {
        if (state is VorgangStartenDefaultsLoaded) {
          _patchDefaults(state.auftragsnummer, state.abteilung);
        }
        if (state is MandantGespeichert) {
          unawaited(_uebernehmeGespeicherten(state.mandant));
        }
      },
      child: ReactiveForm(
        formGroup: _form,
        child: Column(
          children: [
            Expanded(
              child: VorgangStartenSektionen(
                rechtsgebiet: _rechtsgebiet,
                istVerkehrsunfall: _istVerkehrsunfall,
                onRechtsgebietChanged: _onRechtsgebietChanged,
                referenzManuallyEdited: _referenzManuallyEdited,
                onReferenzReset: _resetReferenz,
                mandanten: _mandanten,
                selectedMandantId: _selectedMandantId,
                onMandantGewaehlt: _uebernehmeMandant,
                onAuswahlAufheben: () =>
                    setState(() => _selectedMandantId = null),
                onKennzeichenGewaehlt: (kennzeichen) => _form
                    .control('mandantKennzeichen')
                    .updateValue(kennzeichen),
                onMandantBestaetigt: _onMandantBestaetigt,
                onVorlageAusfuellen: _vorlageAusfuellen,
                onZumPostfach: _zumPostfach,
              ),
            ),
            VorgangAktionsleiste(
              zeigeZentralruf: _istVerkehrsunfall,
              onSpeichern: () => unawaited(_absenden(zentralruf: false)),
              onZentralruf: () => unawaited(_absenden(zentralruf: true)),
            ),
          ],
        ),
      ),
    );
  }
}
