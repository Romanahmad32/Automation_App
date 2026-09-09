import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_bindung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_entscheidung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_aktionsleiste.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_defaults_beobachter.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_reader.dart';
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

  /// Ob der Anwalt das Rechtsgebiet von Hand gesetzt hat. Solange nicht, folgt
  /// es der Abteilung (§7.1) — dasselbe Muster wie bei der Referenz-Vorschau
  /// darunter, samt sichtbarem Weg zurück.
  bool _rechtsgebietManuell = false;

  /// Der Registerbezug der Seite — Liste und verknüpfter Eintrag; die Regeln
  /// dazu stehen in `mandant_bindung.dart`.
  final MandantenStand _mandanten = MandantenStand();

  bool _referenzManuallyEdited = false;

  /// Der Bestand für die Warnung am Auftragsnummer-Feld (§6.3) — leer, solange
  /// der Nummernstand nicht geladen ist oder der Abruf scheiterte.
  List<int> _belegteNummern = const [];
  String? _nummernJahr;

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
    // Das Rechtsgebiet folgt der Abteilung (§7.1). Zwei Quellen können es
    // ändern: eine andere Abteilung — und der Katalog, der erst nach dem
    // Aufbau eintrifft und die Ableitung überhaupt erst möglich macht.
    final abteilung = _form.control('abteilung').valueChanges;
    _subscriptions.add(abteilung.listen((_) => _syncRechtsgebiet()));
    final katalog = getIt<SachgebietCubit>().stream;
    _subscriptions.add(katalog.listen((_) => _syncRechtsgebiet()));
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
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _form.dispose();
    super.dispose();
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
        Validators.delegate(KennzeichenField.validator),
      ]);
      schadentag.setValidators([Validators.required, dateValidator]);
    } else {
      kennzeichen.setValidators([
        Validators.delegate(KennzeichenField.validator),
      ]);
      schadentag.setValidators([dateValidator]);
    }
    kennzeichen.updateValueAndValidity();
    schadentag.updateValueAndValidity();
  }

  /// Übernimmt ein Rechtsgebiet und zieht nach, was daran hängt: die Pflicht
  /// der Unfallfelder und der Kennzeichen-Teil der Referenz.
  void _setzeRechtsgebiet(String gebiet) {
    setState(() => _rechtsgebiet = gebiet);
    _applyUnfallValidators();
    _syncReferenzVorschau();
  }

  /// Zieht das Rechtsgebiet der Abteilung nach (§7.1) — solange der Anwalt
  /// nicht selbst gewählt hat. Ohne Katalogtreffer bleibt der bisherige Wert
  /// stehen, statt auf Verkehrsrecht zurückzufallen.
  void _syncRechtsgebiet() {
    if (_rechtsgebietManuell || !mounted) return;
    final abgeleitet = rechtsgebietZurAbteilung(_form);
    if (abgeleitet == null ||
        RechtsgebietWert.gleich(abgeleitet, _rechtsgebiet)) {
      return;
    }
    _setzeRechtsgebiet(abgeleitet);
  }

  void _rechtsgebietAbweichend() => setState(() => _rechtsgebietManuell = true);

  void _rechtsgebietFolgtWieder() {
    setState(() => _rechtsgebietManuell = false);
    _syncRechtsgebiet();
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
    final geladen = await MandantenStand.hole();
    if (!mounted || geladen == null) return;
    setState(() => _mandanten.eintraege = geladen);
  }

  void _uebernehmeMandant(Mandant mandant) =>
      setState(() => _mandanten.waehle(_form, mandant));

  /// Gemeinsamer Absende-Pfad für „Speichern" und „Zentralruf ausfüllen":
  /// holt — wenn am Mandanten etwas neu oder geändert ist — die Bestätigung
  /// über die Übersicht (§1.3) und schickt das Speicher-Event. Abgebrochene
  /// Übersicht bricht das Speichern ab.
  Future<void> _absenden({required bool zentralruf}) async {
    final daten = leseVorgangDaten(_form, _rechtsgebiet);
    final entscheidung = await MandantEntscheidung.hole(
      context,
      daten: daten,
      gewaehlt: _mandanten.gewaehlter,
      vorgaengeAmMandanten: _mandanten.vorgaenge,
    );
    if (!entscheidung.bestaetigt || !mounted) return;

    context.read<VorgangStartenBloc>().add(
      SpeichereVorgangEvent(
        daten: daten,
        neuerMandant: entscheidung.neuerMandant,
        aktualisierterMandant: entscheidung.aktualisierterMandant,
        // Die gemerkte Id, nicht die des gewählten Eintrags: Fehlt der Mandant
        // gerade in der Liste, ginge die bekannte Verknüpfung still verloren.
        verknuepfteMandantId: _mandanten.gewaehlteId,
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
    final gewaehlt = _mandanten.gewaehlter;
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
  /// Was dabei mit Liste und Feldern geschieht, steht bei
  /// `MandantenStand.verknuepfeGespeicherten`.
  void _verknuepfeGespeicherten(Mandant mandant) {
    setState(() => _mandanten.verknuepfeGespeicherten(mandant));
    // Nur noch Auffrischung für die Kennzeichen-Auswahl und die Reihenfolge.
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
    return VorgangDefaultsBeobachter(
      form: _form,
      onNummernstandGeladen: (belegteNummern, nummernJahr) => setState(() {
        _belegteNummern = belegteNummern;
        _nummernJahr = nummernJahr;
      }),
      child: BlocListener<VorgangStartenBloc, VorgangStartenState>(
        listener: (context, state) {
          // Jeder Weg, auf dem ein Mandant entstanden sein kann, mündet hier —
          // der Karten-Knopf, das Speichern des Vorgangs und der Fehlerpfad
          // dahinter: Scheitert nach der Anlage das Vorbefüllen, ist der
          // Mandant trotzdem gespeichert und muss verknüpft werden
          // (FALLSTRICKE.md).
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
                  rechtsgebietManuell: _rechtsgebietManuell,
                  // Die Wahl aus der Liste steht nur offen, wenn der Anwalt
                  // ausdrücklich abweichen wollte — sie gilt von da an weiter.
                  onRechtsgebietChanged: _setzeRechtsgebiet,
                  onRechtsgebietAbweichend: _rechtsgebietAbweichend,
                  onRechtsgebietFolgtWieder: _rechtsgebietFolgtWieder,
                  belegteNummern: _belegteNummern,
                  nummernJahr: _nummernJahr,
                  referenzManuallyEdited: _referenzManuallyEdited,
                  onReferenzReset: _resetReferenz,
                  mandanten: _mandanten.eintraege,
                  selectedMandantId: _mandanten.gewaehlteId,
                  onMandantGewaehlt: _uebernehmeMandant,
                  onAuswahlAufheben: () =>
                      setState(() => _mandanten.gewaehlteId = null),
                  vorgaengeAmMandanten: _mandanten.vorgaenge,
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
      ),
    );
  }
}
