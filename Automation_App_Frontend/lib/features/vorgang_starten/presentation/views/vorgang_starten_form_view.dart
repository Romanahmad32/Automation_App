import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_bindung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_entscheidung.dart';
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
  String _rechtsgebiet = RechtsgebietWert.verkehrsrecht;

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

  bool get _istVerkehrsunfall =>
      RechtsgebietWert.istVerkehrsrecht(_rechtsgebiet);

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
    // Kürzel ohne Leerzeichen (§7.1) — ein gespeicherter Altwert wie 'C 03'
    // wird beim Einlesen normalisiert, bevor er in die Referenz wandert.
    final bereinigt = AbteilungKuerzel.normalisiere(abteilung);
    if (bereinigt.isNotEmpty) {
      _form.control('abteilung').updateValue(bereinigt);
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

  void _onRechtsgebietChanged(String gebiet) {
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

  /// Die Zahl für die Umbenennungs-Warnung — gezählt wird in `mandant_bindung`.
  int get _vorgaengeAmMandanten => vorgaengeAmMandanten(_selectedMandantId);

  Mandant? _findeMandant(int id) {
    for (final mandant in _mandanten) {
      if (mandant.id == id) return mandant;
    }
    return null;
  }

  void _uebernehmeMandant(Mandant mandant) {
    uebernimmMandantInFormular(_form, mandant);
    setState(() => _selectedMandantId = mandant.id);
  }

  /// Gemeinsamer Absende-Pfad für „Speichern" und „Zentralruf ausfüllen":
  /// holt — wenn am Mandanten etwas neu oder geändert ist — die Bestätigung
  /// über die Übersicht (§1.3) und schickt das Speicher-Event. Abgebrochene
  /// Übersicht bricht das Speichern ab.
  Future<void> _absenden({required bool zentralruf}) async {
    final daten = leseVorgangDaten(_form, _rechtsgebiet);
    final gewaehlt = _selectedMandantId == null
        ? null
        : _findeMandant(_selectedMandantId!);
    final entscheidung = await MandantEntscheidung.hole(
      context,
      daten: daten,
      gewaehlt: gewaehlt,
      vorgaengeAmMandanten: _vorgaengeAmMandanten,
    );
    if (!entscheidung.bestaetigt || !mounted) return;

    context.read<VorgangStartenBloc>().add(
      SpeichereVorgangEvent(
        daten: daten,
        neuerMandant: entscheidung.neuerMandant,
        aktualisierterMandant: entscheidung.aktualisierterMandant,
        // Die gemerkte Id, nicht `gewaehlt?.id`: Fehlt der Mandant gerade in
        // der Liste, ginge die bekannte Verknüpfung sonst still verloren.
        verknuepfteMandantId: _selectedMandantId,
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

  /// Verknüpft den gerade gespeicherten Mandanten mit der Karte — **synchron**.
  ///
  /// Synchron, weil sonst zwischen dem Ende des Ladezustands (die Knöpfe sind
  /// da wieder frei) und der Verknüpfung ein Fenster offen bliebe: Ein Klick
  /// darin hielte den Mandanten noch für neu und liefe in den Namenskonflikt.
  /// Aus demselben Grund wird die Liste hier schon ergänzt, statt auf das
  /// Nachladen zu warten — das kann scheitern, ohne es zu melden.
  ///
  /// Die Formularfelder bleiben unangetastet: Der Mandant ist aus ihnen
  /// entstanden, und auf dem Zentralruf-Weg liegen bis zu drei Minuten
  /// dazwischen, in denen der Anwalt weitergetippt haben kann (§1.3 — die App
  /// „überschreibt nichts stillschweigend"). Felder füllt nur, wer über das
  /// Dropdown einen Mandanten *auswählt*: `_uebernehmeMandant`.
  void _verknuepfeGespeicherten(Mandant mandant) {
    setState(() {
      _mandanten = [..._mandanten.where((m) => m.id != mandant.id), mandant];
      _selectedMandantId = mandant.id;
    });
    // Nur noch Auffrischung für Kennzeichen-Chips und Reihenfolge.
    unawaited(_ladeMandanten());
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
        // Jeder Weg, auf dem ein Mandant entstanden sein kann, mündet hier —
        // der Karten-Knopf, das Speichern des Vorgangs und der Fehlerpfad
        // dahinter: Scheitert nach der Anlage das Vorbefüllen, ist der Mandant
        // trotzdem gespeichert und muss verknüpft werden (FALLSTRICKE.md).
        final gespeicherter = switch (state) {
          MandantGespeichert(:final mandant) => mandant,
          VorgangGespeichert(:final gespeicherterMandant) ||
          VorgangStartenError(
            :final gespeicherterMandant,
          ) => gespeicherterMandant,
          _ => null,
        };
        if (gespeicherter != null) _verknuepfeGespeicherten(gespeicherter);
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
                vorgaengeAmMandanten: _vorgaengeAmMandanten,
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
