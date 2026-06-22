import 'dart:io';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schritt 4: Das bestätigte Dokument in die Akte des Mandanten ablegen (§3.6).
/// Ein Mandant kann mehrere Akten-Ordner haben (verschiedene Rubriken); der
/// Zielordner und der Unterordner (Fall) sind daher wählbar oder neu anlegbar.
/// Existiert der Mandant noch nicht, wird er hier — mit den Formulardaten
/// vorbelegt — angelegt. Alternativ kann das Dokument an einen frei wählbaren
/// Ort kopiert werden (das Original bleibt als Sicherung im Generated-Ordner).
class WizardStepSave extends StatelessWidget {
  const WizardStepSave({super.key});

  @override
  Widget build(BuildContext context) {
    final editedState = context.watch<EditedDocumentBloc>().state;
    final outputPath = editedState is EditedDocumentLoaded
        ? editedState.path
        : null;

    if (outputPath == null) {
      return const Center(
        child: Text(
          'Es wurde noch kein Dokument erstellt.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AktenAblageSection(outputPath: outputPath),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _ManuellSpeichern(outputPath: outputPath),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const _VorgangAbschliessenSection(),
            ],
          ),
        ),
      ),
    );
  }
}

const String _neuSentinel = '__neu__';

class _AktenAblageSection extends StatefulWidget {
  final String outputPath;

  const _AktenAblageSection({required this.outputPath});

  @override
  State<_AktenAblageSection> createState() => _AktenAblageSectionState();
}

class _AktenAblageSectionState extends State<_AktenAblageSection> {
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
  final _stichwortController = TextEditingController(text: 'Unfall');
  final _datumController = TextEditingController();
  final _kennzeichenController = TextEditingController();

  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    context.read<AblageCubit>().laden();
  }

  @override
  void dispose() {
    _neueAkteController.dispose();
    _stichwortController.dispose();
    _datumController.dispose();
    _kennzeichenController.dispose();
    super.dispose();
  }

  /// Belegt Datum/Kennzeichen einmalig aus den Formulardaten vor, sobald der
  /// Speicherschritt erreicht ist (dann liegen die Eingaben aus Schritt 1 vor).
  void _prefill() {
    if (_prefilled) return;
    _prefilled = true;
    final wizard = context.read<WizardCubit>().state;
    final fields = wizard.selectedFormTemplate?.fields ?? const [];
    final data = wizard.formData ?? const {};
    _datumController.text = ursachendatumAusFormular(fields, data) ?? '';
    _kennzeichenController.text = kennzeichenAusFormular(data) ?? '';
  }

  Future<void> _neuerMandant() async {
    final wizardData = context.read<WizardCubit>().state.formData ?? const {};
    final vorschlag = mandantDatenAusFormular(wizardData);
    final cubit = context.read<AblageCubit>();
    final request = await showDialog<CreateMandantRequest>(
      context: context,
      builder: (_) => _NeuerMandantDialog(vorschlag: vorschlag),
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
  }

  String _aktenOrdner() {
    if (_neueAkte || (_mandant?.aktenOrdnernamen.isEmpty ?? true)) {
      return _neueAkteController.text.trim();
    }
    return _gewaehlteAkte ?? '';
  }

  String _baueUnterordner() {
    final stichwort = _stichwortController.text.trim().isEmpty
        ? 'Unfall'
        : _stichwortController.text.trim();
    final datum = _datumController.text.trim();
    final kennzeichen = _kennzeichenController.text.trim();
    var name = stichwort;
    if (datum.isNotEmpty) name += ' v. $datum';
    if (kennzeichen.isNotEmpty) name += ' $kennzeichen';
    return name;
  }

  String _unterordnerName() =>
      _neuerFall ? _baueUnterordner() : (_gewaehlterFall ?? _baueUnterordner());

  /// Vorhandene Fälle des aktuell gewählten Akten-Ordners.
  List<String> _vorhandeneFaelle(List<Akte> akten) {
    final ordner = _aktenOrdner();
    if (ordner.isEmpty) return const [];
    for (final a in akten) {
      if (a.ordnername == ordner) return a.faelle.map((f) => f.name).toList();
    }
    return const [];
  }

  void _ablegen() {
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
    context.read<AblageCubit>().ablegenFuerMandant(
      mandantId: mandant.id,
      aktenOrdnername: ordner,
      unterordnerName: unter,
      quelldateiPfad: widget.outputPath,
    );
  }

  void _hinweis(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          } else if (state.status == AblageStatus.erfolg) {
            // Ablage geglückt: den gewählten Vorgang auf „abgelegt" weiter-
            // schalten und Ablageort vermerken (nur vorwärts).
            final vorgang = context.read<WizardCubit>().state.selectedVorgang;
            if (vorgang != null &&
                vorgang.status.index < VorgangStatus.abgelegt.index) {
              getIt<VorgangCubit>().aktualisiere(
                vorgang.copyWith(
                  status: VorgangStatus.abgelegt,
                  dokumentPfad: state.zielpfad,
                  aktenOrdner: _aktenOrdner(),
                ),
              );
            }
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
            return _KeinStammordnerHinweis();
          }

          if (state.status == AblageStatus.erfolg) {
            return _ErfolgAnzeige(
              zielpfad: state.zielpfad ?? '',
              onErneut: () => context.read<AblageCubit>().laden(),
            );
          }

          return _ablageFormular(context, state);
        },
      ),
    );
  }

  Widget _ablageFormular(BuildContext context, AblageState state) {
    final theme = Theme.of(context);
    final isFiling = state.status == AblageStatus.filing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.folder_special, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'In Akte ablegen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Das Dokument wird unter dem Stammordner in der Akte des Mandanten '
          'gespeichert. Existiert die Akte noch nicht, wird sie angelegt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        _mandantAuswahl(context, state),
        if (_mandant != null) ...[
          const SizedBox(height: 16),
          _akteAuswahl(context, state),
          const SizedBox(height: 16),
          _unterordnerAuswahl(context, state),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isFiling ? null : _ablegen,
            icon: isFiling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_folder_upload),
            label: const Text('In Akte ablegen'),
          ),
        ],
      ],
    );
  }

  // ── Mandant ───────────────────────────────────────────────────────────────
  Widget _mandantAuswahl(BuildContext context, AblageState state) {
    final theme = Theme.of(context);
    if (_mandant != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.person, color: theme.colorScheme.primary),
          title: Text(
            _mandant!.anzeigename.isEmpty
                ? '(ohne Namen)'
                : _mandant!.anzeigename,
          ),
          subtitle: const Text('Mandant'),
          trailing: TextButton(
            onPressed: () => setState(() => _mandant = null),
            child: const Text('Ändern'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.mandanten.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bestehenden Mandanten wählen',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_search),
            ),
            items: [
              for (final m in state.mandanten)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                    m.anzeigename.isEmpty ? '(ohne Namen)' : m.anzeigename,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              _waehleMandant(state.mandanten.firstWhere((m) => m.id == id));
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _neuerMandant,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Neuen Mandanten anlegen'),
        ),
        const SizedBox(height: 4),
        Text(
          'Der neue Mandant wird mit den Daten aus dem Formular vorbelegt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  // ── Akte (Ordner) ───────────────────────────────────────────────────────
  Widget _akteAuswahl(BuildContext context, AblageState state) {
    final ordner = _mandant!.aktenOrdnernamen;
    final children = <Widget>[];

    if (ordner.isNotEmpty) {
      children.add(
        DropdownButtonFormField<String>(
          initialValue: _neueAkte ? _neuSentinel : _gewaehlteAkte,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Akte (Ordner des Mandanten)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          items: [
            for (final o in ordner) DropdownMenuItem(value: o, child: Text(o)),
            const DropdownMenuItem(
              value: _neuSentinel,
              child: Text('＋ Neue Akte anlegen …'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              if (value == _neuSentinel) {
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
          },
        ),
      );
    }

    if (_neueAkte || ordner.isEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(
        TextField(
          controller: _neueAkteController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Neuer Akten-Ordner',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.create_new_folder_outlined),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // ── Unterordner (Fall) ────────────────────────────────────────────────────
  Widget _unterordnerAuswahl(BuildContext context, AblageState state) {
    final theme = Theme.of(context);
    final faelle = _vorhandeneFaelle(state.akten);
    final children = <Widget>[];

    if (faelle.isNotEmpty) {
      children.add(
        DropdownButtonFormField<String>(
          initialValue: _neuerFall ? _neuSentinel : _gewaehlterFall,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Unterordner (Fall)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.topic_outlined),
          ),
          items: [
            for (final f in faelle) DropdownMenuItem(value: f, child: Text(f)),
            const DropdownMenuItem(
              value: _neuSentinel,
              child: Text('＋ Neuen Unterordner anlegen …'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              if (value == _neuSentinel) {
                _neuerFall = true;
              } else {
                _neuerFall = false;
                _gewaehlterFall = value;
              }
            });
          },
        ),
      );
    }

    if (_neuerFall || faelle.isEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _stichwortController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Stichwort',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _datumController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Ursachendatum',
                  hintText: 'TT.MM.JJJJ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _kennzeichenController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Kennzeichen (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          'Ordnername: ${_baueUnterordner()}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Dialog zum Anlegen eines neuen Mandanten direkt aus dem Speicherschritt,
/// vorbelegt mit den (best-effort) aus dem Formular gelesenen Daten.
class _NeuerMandantDialog extends StatefulWidget {
  final FormularMandantDaten vorschlag;

  const _NeuerMandantDialog({required this.vorschlag});

  @override
  State<_NeuerMandantDialog> createState() => _NeuerMandantDialogState();
}

class _NeuerMandantDialogState extends State<_NeuerMandantDialog> {
  late final _vorname = TextEditingController(text: widget.vorschlag.vorname);
  late final _nachname = TextEditingController(text: widget.vorschlag.nachname);
  late final _strasse = TextEditingController(
    text: widget.vorschlag.strasseHausnummer,
  );
  late final _plz = TextEditingController(text: widget.vorschlag.postleitzahl);
  late final _ort = TextEditingController(text: widget.vorschlag.ort);
  late final _email = TextEditingController(
    text: widget.vorschlag.emailAdresse,
  );
  late final _telefon = TextEditingController(
    text: widget.vorschlag.telefonnummer,
  );

  @override
  void dispose() {
    for (final c in [
      _vorname,
      _nachname,
      _strasse,
      _plz,
      _ort,
      _email,
      _telefon,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Mandanten anlegen'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _feld(_vorname, 'Vorname')),
                  const SizedBox(width: 12),
                  Expanded(child: _feld(_nachname, 'Nachname *')),
                ],
              ),
              const SizedBox(height: 12),
              _feld(_strasse, 'Straße und Hausnummer'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: _feld(_plz, 'PLZ')),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: _feld(_ort, 'Ort')),
                ],
              ),
              const SizedBox(height: 12),
              _feld(_email, 'E-Mail-Adresse'),
              const SizedBox(height: 12),
              _feld(_telefon, 'Telefonnummer'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_nachname.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Der Nachname ist ein Pflichtfeld'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              CreateMandantRequest(
                vorname: _vorname.text.trim(),
                nachname: _nachname.text.trim(),
                strasseHausnummer: _strasse.text.trim(),
                postleitzahl: _plz.text.trim(),
                ort: _ort.text.trim(),
                emailAdresse: _email.text.trim(),
                telefonnummer: _telefon.text.trim(),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }

  Widget _feld(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ErfolgAnzeige extends StatelessWidget {
  final String zielpfad;
  final VoidCallback onErneut;

  const _ErfolgAnzeige({required this.zielpfad, required this.onErneut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'In der Akte abgelegt:',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SelectableText(
          zielpfad,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => _imExplorerZeigen(zielpfad),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Im Explorer zeigen'),
            ),
            TextButton.icon(
              onPressed: onErneut,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut ablegen'),
            ),
          ],
        ),
      ],
    );
  }

  void _imExplorerZeigen(String pfad) {
    // Markiert die Datei im Windows-Explorer.
    Process.run('explorer', ['/select,', pfad]);
  }
}

class _KeinStammordnerHinweis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kein Stammordner für das Aktensystem festgelegt. Hinterlegen Sie '
              'ihn in den Einstellungen, um Dokumente automatisch in die Akte '
              'abzulegen. Alternativ können Sie unten manuell speichern.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Abschluss des Vorgangs (Req. 3.2 / 3.7): markiert den Auftrag als erledigt
/// (Status „versendet"), zählt die laufende Auftragsnummer in den Einstellungen
/// hoch und nimmt den Vorgang damit ins Sachgebiete-Register auf. Greift den
/// gewählten Vorgang live aus dem [VorgangCubit] ab, damit der Status nach dem
/// Abschluss sofort umschlägt.
class _VorgangAbschliessenSection extends StatelessWidget {
  const _VorgangAbschliessenSection();

  Future<void> _abschliessen(BuildContext context, Vorgang vorgang) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vorgang abschließen?'),
        content: Text(
          'Der Vorgang „${vorgang.referenz}" wird als erledigt markiert und '
          'ins Sachgebiete-Register aufgenommen. Die laufende Auftragsnummer '
          'wird für den nächsten Auftrag um eins hochgezählt.\n\n'
          'Das Versenden der E-Mail (§3.7) erfolgt weiterhin manuell.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abschließen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !context.mounted) return;
    await getIt<VorgangCubit>().abschliessen(vorgang);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vorgang abgeschlossen und ins Register aufgenommen. Die laufende '
          'Auftragsnummer wurde hochgezählt.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = context.watch<WizardCubit>().state.selectedVorgang;

    if (selected == null) {
      return Column(
        children: [
          Text(
            'Vorgang abschließen',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Diesem Dokument ist kein Vorgang zugeordnet. Wählen Sie im ersten '
            'Schritt einen Vorgang, um ihn nach dem Versand abzuschließen '
            '(Auftragsnummer hochzählen, Registereintrag).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      );
    }

    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final aktuell =
            getIt<VorgangCubit>().findeZuReferenz(selected.referenz) ?? selected;
        final abgeschlossen = aktuell.status == VorgangStatus.versendet;

        return Column(
          children: [
            Text(
              'Vorgang abschließen',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${aktuell.referenz} · Status: ${aktuell.status.displayName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            if (abgeschlossen)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Abgeschlossen und ins Register aufgenommen.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _abschliessen(context, aktuell),
                icon: const Icon(Icons.task_alt),
                label: const Text('Vorgang abschließen'),
              ),
          ],
        );
      },
    );
  }
}

/// Sekundärer Weg: das Dokument an einen frei wählbaren Ort kopieren.
class _ManuellSpeichern extends StatefulWidget {
  final String outputPath;

  const _ManuellSpeichern({required this.outputPath});

  @override
  State<_ManuellSpeichern> createState() => _ManuellSpeichernState();
}

class _ManuellSpeichernState extends State<_ManuellSpeichern> {
  String? _savedPath;
  String? _saveError;

  Future<void> _saveDocument() async {
    final fileName = widget.outputPath.split(RegExp(r'[\\/]')).last;
    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Dokument speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (targetPath == null) return;

    try {
      await File(widget.outputPath).copy(targetPath);
      setState(() {
        _savedPath = targetPath;
        _saveError = null;
      });
    } on FileSystemException catch (e) {
      setState(() => _saveError = 'Speichern fehlgeschlagen: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'An anderen Ort speichern',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saveDocument,
          icon: const Icon(Icons.folder_open),
          label: Text(
            _savedPath == null
                ? 'Speicherort wählen & speichern'
                : 'Erneut speichern …',
          ),
        ),
        if (_savedPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Gespeichert unter:\n$_savedPath',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(
            _saveError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
