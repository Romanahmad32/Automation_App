import 'dart:async';

import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/usecases/lade_vollmacht_vorlagen.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_vorlage_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// „Vollmacht-Vorlagen" in den Einstellungen (§4.11): je Art der feste
/// Dateiname und ob die App die Datei findet, dazu „Ordner öffnen".
///
/// Keine Pflegeoberfläche wie in „Vorlagen verwalten" — die Felder der
/// Vollmacht sind fest. Der Anwalt tauscht eine Datei im Explorer aus, und
/// diese Sektion zeigt, was die App danach benutzt.
///
/// Geladen wie die Ordnerzustände daneben (`OrdnerZustandListe`): beim
/// Aufgehen und nach jedem Speichern der Kanzleidaten, weil sich mit dem
/// Vorlagenordner auch dieser Unterordner ändert. Fehler bleiben stumm — die
/// Sektion ist Auskunft neben den Feldern, kein Arbeitsschritt.
class VollmachtVorlagenSektion extends StatefulWidget {
  const VollmachtVorlagenSektion({super.key});

  @override
  State<VollmachtVorlagenSektion> createState() =>
      VollmachtVorlagenSektionState();
}

class VollmachtVorlagenSektionState extends State<VollmachtVorlagenSektion> {
  VollmachtVorlagenStand? _stand;

  @override
  void initState() {
    super.initState();
    unawaited(_laden());
  }

  Future<void> _laden() async {
    VollmachtVorlagenStand? geladen;
    try {
      final ergebnis = await getIt<LadeVollmachtVorlagen>()(const NoParams());
      if (ergebnis case Right(value: final stand)) geladen = stand;
    } catch (_) {
      geladen = null;
    }
    if (!mounted) return;
    setState(() => _stand = geladen);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KanzleiSettingsBloc, KanzleiSettingsState>(
      listenWhen: (_, neu) =>
          neu is KanzleiSettingsLoaded &&
          neu.gespeichert == KanzleiSettingsBereich.kanzlei,
      listener: (_, _) => unawaited(_laden()),
      child: _inhalt(context),
    );
  }

  Widget _inhalt(BuildContext context) {
    final stand = _stand;
    if (stand == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Vollmacht-Vorlagen',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Ordner öffnen'),
              onPressed: () => DateiOeffner.oeffneOrdner(stand.ordner),
            ),
            IconButton(
              tooltip: 'Erneut prüfen',
              icon: const Icon(Icons.refresh),
              onPressed: _laden,
            ),
          ],
        ),
        Text(
          stand.ordner,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        for (final vorlage in stand.vorlagen)
          VollmachtVorlageZeile(vorlage: vorlage),
      ],
    );
  }
}
