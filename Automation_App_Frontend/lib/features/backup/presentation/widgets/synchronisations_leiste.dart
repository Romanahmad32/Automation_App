import 'package:automation_app/core/general_classes/datenstand_signal.dart';
import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:automation_app/features/backup/presentation/widgets/synchronisations_details.dart';
import 'package:automation_app/features/backup/presentation/widgets/synchronisations_bereich.dart';
import 'package:automation_app/features/backup/presentation/widgets/synchronisations_stand_anzeige.dart';
import 'package:flutter/material.dart';

/// Prüft in der Shell weiter; die Bedienung erscheint in den Einstellungen.
class SynchronisationsLeiste extends StatefulWidget {
  final Widget? child;
  const SynchronisationsLeiste({super.key, this.child});

  @override
  State<SynchronisationsLeiste> createState() => SynchronisationsLeisteState();
}

class SynchronisationsLeisteState extends State<SynchronisationsLeiste>
    with WidgetsBindingObserver {
  late final BackupRepository _backup;
  Timer? _takt;
  UebergabeStand? _stand;
  String? _meldung;
  String? _uebernahmeMeldung;
  bool _prueft = false;
  bool _arbeitet = false;
  String? _aktion;
  DateTime? _geprueft;

  @override
  void initState() {
    super.initState();
    _backup = getIt<BackupRepository>();
    _uebernahmeMeldung = DatenstandSignal.nimmMeldung();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_pruefen());
    _takt = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_pruefen()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_pruefen());
  }

  @override
  void dispose() {
    _takt?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pruefen() async {
    if (_prueft || _arbeitet) return;
    _prueft = true;
    try {
      final stand = await _backup.uebergabeStand();
      if (!mounted) return;
      setState(() {
        _stand = stand;
        _geprueft = DateTime.now();
        _meldung = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _meldung =
            'Status nicht prüfbar. Bitte erneut prüfen; der lokale Stand bleibt nutzbar.',
      );
    } finally {
      _prueft = false;
    }
  }

  Future<void> _bereitstellen() async {
    setState(() {
      _arbeitet = true;
      _aktion = 'Sicherung wird erstellt und im gemeinsamen Ordner abgelegt …';
      _meldung = null;
    });
    try {
      await _backup.jetztBereitstellen();
    } catch (fehler) {
      if (mounted) {
        setState(() => _meldung = 'Bereitstellen nicht bestätigt: $fehler');
      }
    } finally {
      if (mounted) {
        setState(() {
          _arbeitet = false;
          _aktion = null;
        });
      }
    }
    if (mounted && _meldung == null) await _pruefen();
  }

  Future<void> _uebernehmen() async {
    final stand = _stand;
    if (stand?.angebot == null) return;
    final bestaetigt = await bestaetigen(
      context,
      titel: stand!.konflikt
          ? 'Unterschiedliche Änderungen – Stand auswählen'
          : 'Stand von ${stand.angebot!.rechnername} übernehmen?',
      text:
          '${stand.konflikt ? '${stand.hinweis}\n\n' : ''}'
          'Der Stand vom ${SicherungsZeitpunkt.beschreibe(stand.angebot!.gesichertAm)} ersetzt die Daten auf diesem Rechner. '
          'Der bisherige gespeicherte Bestand wird vorher gesichert. '
          'Bitte offene Eingaben zuerst speichern. Nicht gespeicherte Eingaben werden beim Neuladen verworfen.',
      bestaetigung: stand.konflikt
          ? 'Hiesigen Stand ersetzen'
          : 'Prüfen und übernehmen',
    );
    if (!bestaetigt || !mounted) return;
    setState(() {
      _arbeitet = true;
      _aktion = 'Datei wird geladen, geprüft und übernommen. Bitte warten …';
      _meldung = null;
    });
    try {
      final meldung = await _backup.uebernehmeStand(
        pruefkennung: stand.pruefkennung,
        konfliktBestaetigt: stand.konflikt,
      );
      if (mounted) setState(() => _meldung = meldung);
    } catch (fehler) {
      if (mounted) {
        setState(
          () => _meldung =
              'Übernahme nicht bestätigt: $fehler. Bitte den Stand erneut prüfen.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _arbeitet = false;
          _aktion = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final inhalt = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: child == null ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (_uebernahmeMeldung != null)
          MaterialBanner(
            content: Text(_uebernahmeMeldung!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _uebernahmeMeldung = null),
                child: const Text('Verstanden'),
              ),
            ],
          ),
        if (child != null)
          Expanded(
            child: SynchronisationsBereich(anzeige: _anzeige, child: child),
          )
        else
          _anzeige(context),
      ],
    );
    return child == null ? SingleChildScrollView(child: inhalt) : inhalt;
  }

  Widget _anzeige(BuildContext context) {
    final stand = _stand;
    final problem =
        _meldung != null ||
        stand?.konflikt == true ||
        stand?.zustand == 'nichtErreichbar' ||
        (stand?.letzteSicherung?.offenerFehler ?? false);
    final titel =
        _aktion ??
        _meldung ??
        (stand == null
            ? 'Arbeitsplatzwechsel wird geprüft …'
            : SynchronisationsDetails.titel(stand));
    return Material(
      color: problem
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(titel, style: Theme.of(context).textTheme.bodyMedium),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: _arbeitet ? null : () => unawaited(_details()),
                      child: const Text('Details'),
                    ),
                    if (stand?.angebot != null)
                      FilledButton.tonal(
                        onPressed: _arbeitet
                            ? null
                            : () => unawaited(_uebernehmen()),
                        child: const Text('Stand übernehmen …'),
                      ),
                    OutlinedButton(
                      onPressed:
                          _arbeitet ||
                              stand == null ||
                              stand.ablageOrdner.isEmpty
                          ? null
                          : () => unawaited(_bereitstellen()),
                      child: const Text('Jetzt bereitstellen'),
                    ),
                    IconButton(
                      onPressed: _arbeitet ? null : () => unawaited(_pruefen()),
                      tooltip: 'Jetzt auf eingehende Stände prüfen',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SynchronisationsStandAnzeige(stand: stand, geprueft: _geprueft),
          ],
        ),
      ),
    );
  }

  Future<void> _details() =>
      SynchronisationsDetails.zeigen(context, _stand, _geprueft);
}
