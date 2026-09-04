import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/ablage_abschluss.dart';
import 'package:automation_app/features/word_automation/presentation/utils/ablage_durchfuehrung.dart';
import 'package:automation_app/features/word_automation/presentation/utils/akten_auswahl.dart';
import 'package:automation_app/features/word_automation/presentation/utils/fall_ordner_felder.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:automation_app/features/word_automation/presentation/utils/mandant_vorauswahl.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_constants.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_erfolg_anzeige.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/akten_ablage_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/kein_stammordner_hinweis.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/neuer_mandant_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Primärer Weg im Speicherschritt: das bestätigte Dokument in die Akte des
/// Mandanten ablegen (§6.1). Wählt/legt Mandant, Akten-Ordner und Unterordner
/// (Fall), lässt wählen, welche Fassungen dorthin sollen (Word, PDF oder
/// beide), und übergibt die Ablage an [starteAblage]. Was danach passiert —
/// Vorgang fortschalten, Arbeitsordner aufräumen — steht in
/// [schliesseAblageAb].
class AktenAblageSection extends StatefulWidget {
  final String outputPath;

  const AktenAblageSection({super.key, required this.outputPath});

  @override
  State<AktenAblageSection> createState() => _AktenAblageSectionState();
}

class _AktenAblageSectionState extends State<AktenAblageSection> {
  /// Gewählter bzw. neu angelegter Mandant (null = noch keiner gewählt).
  Mandant? _mandant;

  /// Gewählter vorhandener Akten-Ordner des Mandanten.
  String? _gewaehlteAkte;

  /// Neuen Akten-Ordner anlegen statt vorhandenen wählen.
  bool _neueAkte = false;

  /// Gewählter vorhandener Unterordner (Fall).
  String? _gewaehlterFall;

  /// Neuen Unterordner anlegen (Default).
  bool _neuerFall = true;

  final _neueAkteController = TextEditingController();
  final _fallFelder = FallOrdnerFelder();

  /// Welche Fassungen in die Akte gehen. Voreinstellung ist die Word-Datei:
  /// die bearbeitbare Fassung, mit der der Assistent weiterarbeitet.
  AblageFormat _format = AblageFormat.word;

  /// Läuft gerade die PDF-Erzeugung? Sie geht der Ablage voraus, dauert
  /// Sekunden und ist am Cubit noch nicht zu sehen — ohne diesen Riegel
  /// klickt der Anwalt ein zweites Mal.
  bool _pdfLaeuft = false;

  /// Automatische Mandanten-Vorauswahl aus dem Vorgang nur einmal versuchen,
  /// damit ein bewusstes „Ändern" des Nutzers nicht wieder überschrieben wird.
  bool _mandantVorbelegt = false;

  @override
  void initState() {
    super.initState();
    context.read<AblageCubit>().laden();
  }

  @override
  void dispose() {
    _neueAkteController.dispose();
    _fallFelder.dispose();
    super.dispose();
  }

  /// Belegt Datum/Kennzeichen aus den Formulardaten vor, sobald der
  /// Speicherschritt erreicht ist (dann liegen die Eingaben aus Schritt 1 vor).
  void _prefill() {
    final wizard = context.read<WizardCubit>().state;
    _fallFelder.vorbelegen(
      wizard.selectedFormTemplate?.fields ?? const [],
      wizard.formData ?? const {},
    );
  }

  /// Frischester Stand des im Wizard gewählten Vorgangs — die Auswahl im
  /// Wizard kann veraltet sein (inzwischen zurückgeflossene Feldwerte oder
  /// eine eingetroffene Antwort gingen sonst verloren).
  Vorgang? _aktuellerVorgang() {
    final gewaehlt = context.read<WizardCubit>().state.selectedVorgang;
    if (gewaehlt == null) return null;
    return getIt<VorgangCubit>().findeZuReferenz(gewaehlt.referenz) ?? gewaehlt;
  }

  /// Wählt den Mandanten des Vorgangs automatisch vor, sobald die
  /// Mandantenliste geladen ist (nur einmal, und nur solange der Nutzer noch
  /// keinen gewählt hat).
  void _mandantVorbelegen(List<Mandant> mandanten) {
    if (_mandantVorbelegt) return;
    _mandantVorbelegt = true;
    if (_mandant != null) return;
    final mandant = mandantZuVorgang(_aktuellerVorgang(), mandanten);
    if (mandant != null) _waehleMandant(mandant);
  }

  Future<void> _neuerMandant() async {
    final wizardData = context.read<WizardCubit>().state.formData ?? const {};
    final vorschlag = mandantDatenAusFormular(wizardData);
    final cubit = context.read<AblageCubit>();
    final request = await showDialog<CreateMandantRequest>(
      context: context,
      builder: (_) => NeuerMandantDialog(vorschlag: vorschlag),
    );
    if (request == null) return;
    final mandant = await cubit.mandantAnlegen(request);
    if (mandant != null && mounted) _waehleMandant(mandant);
  }

  void _waehleMandant(Mandant m) {
    setState(() {
      _mandant = m;
      if (m.aktenOrdnernamen.isEmpty) {
        _neueAkte = true;
        _neueAkteController.text = m.anzeigename;
        _gewaehlteAkte = null;
      } else {
        _neueAkte = false;
        _gewaehlteAkte = m.aktenOrdnernamen.first;
      }
      _gewaehlterFall = null;
      _neuerFall = true;
    });
    _faelleNachladen();
  }

  /// Die vorhandenen Fälle des gewählten Akten-Ordners nachholen — der
  /// Akten-Scan liefert sie nicht mehr mit (siehe `AblageCubit.faelleLaden`).
  void _faelleNachladen() {
    context.read<AblageCubit>().faelleLaden(_aktenOrdner());
  }

  void _onAkteDropdownChanged(String? value) {
    setState(() {
      if (value == neuSentinel) {
        _neueAkte = true;
        if (_neueAkteController.text.trim().isEmpty) {
          _neueAkteController.text = _mandant!.anzeigename;
        }
      } else {
        _neueAkte = false;
        _gewaehlteAkte = value;
      }
      _gewaehlterFall = null;
      _neuerFall = true;
    });
    _faelleNachladen();
  }

  void _onFallDropdownChanged(String? value) {
    setState(() {
      if (value == neuSentinel) {
        _neuerFall = true;
      } else {
        _neuerFall = false;
        _gewaehlterFall = value;
      }
    });
  }

  String _aktenOrdner() {
    if (_neueAkte || (_mandant?.aktenOrdnernamen.isEmpty ?? true)) {
      return _neueAkteController.text.trim();
    }
    return _gewaehlteAkte ?? '';
  }

  String _unterordnerName() => _neuerFall
      ? _fallFelder.ordnername
      : (_gewaehlterFall ?? _fallFelder.ordnername);

  Future<void> _ablegen() async {
    final mandant = _mandant;
    if (mandant == null) return;
    final ordner = _aktenOrdner();
    final unter = _unterordnerName().trim();
    if (ordner.isEmpty) {
      _hinweis('Bitte eine Akte wählen oder einen Ordnernamen eingeben.');
      return;
    }
    if (unter.isEmpty) {
      _hinweis('Bitte einen Unterordner wählen oder anlegen.');
      return;
    }

    setState(() => _pdfLaeuft = _format.mitPdf);
    await starteAblage(
      context,
      mandantId: mandant.id,
      aktenOrdnername: ordner,
      unterordnerName: unter,
      wordPfad: widget.outputPath,
      format: _format,
    );
    if (mounted) setState(() => _pdfLaeuft = false);
  }

  void _hinweis(String text) {
    Rueckmeldung.zeigeHinweis(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WizardCubit, WizardState>(
      listenWhen: (previous, current) => current.currentStep == WizardStep.save,
      listener: (context, state) => _prefill(),
      child: BlocConsumer<AblageCubit, AblageState>(
        listener: (context, state) {
          if (state.status == AblageStatus.fehler && state.message != null) {
            _hinweis(state.message!);
          } else if (state.status == AblageStatus.ready) {
            _mandantVorbelegen(state.mandanten);
          } else if (state.status == AblageStatus.konflikt) {
            klaereAblageKonflikt(context, state.konfliktPfade);
          } else if (state.status == AblageStatus.erfolg) {
            schliesseAblageAb(
              context,
              vorgang: _aktuellerVorgang(),
              zielpfade: state.zielpfade,
              aktenOrdner: _aktenOrdner(),
            );
          }
        },
        builder: (context, state) {
          if (state.status == AblageStatus.loading ||
              state.status == AblageStatus.initial) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (!state.stammordnerGesetzt) {
            return const KeinStammordnerHinweis();
          }

          if (state.status == AblageStatus.erfolg) {
            return AblageErfolgAnzeige(
              zielpfade: state.zielpfade,
              onErneut: () => context.read<AblageCubit>().laden(),
            );
          }

          return AktenAblageFormular(
            mandant: _mandant,
            mandanten: state.mandanten,
            neueAkte: _neueAkte,
            gewaehlteAkte: _gewaehlteAkte,
            neuerFall: _neuerFall,
            gewaehlterFall: _gewaehlterFall,
            faelle: faelleZuOrdner(state.akten, _aktenOrdner()),
            neueAkteController: _neueAkteController,
            stichwortController: _fallFelder.stichwort,
            datumController: _fallFelder.datum,
            kennzeichenController: _fallFelder.kennzeichen,
            vorschau: _fallFelder.ordnername,
            format: _format,
            isFiling: state.status == AblageStatus.filing || _pdfLaeuft,
            onWaehleMandant: _waehleMandant,
            onNeuerMandant: _neuerMandant,
            onAendernMandant: () => setState(() => _mandant = null),
            onAkteDropdownChanged: _onAkteDropdownChanged,
            onNeueAkteTextChanged: () => setState(() {}),
            onFallDropdownChanged: _onFallDropdownChanged,
            onUnterordnerTextChanged: () => setState(() {}),
            onFormatChanged: (format) => setState(() => _format = format),
            onAblegen: _ablegen,
          );
        },
      ),
    );
  }
}
