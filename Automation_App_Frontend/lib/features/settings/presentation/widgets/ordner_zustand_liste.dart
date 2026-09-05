import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_zustand_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Fuß der Ordner-Sektion: je Ordner eine Zeile, was der Dienst
/// tatsächlich nutzt (`GET /api/Settings/ordner`).
///
/// **Gesammelt am Fuß und nicht unter jedem Feld** — drei der fünf Felder
/// stecken im zugeklappten Aufklapper „Abweichende Ordner festlegen". Ihre
/// Zeile stünde dort in aller Regel ungelesen, ausgerechnet die zum
/// fehlenden Anker. Zusammen gelesen beantworten die fünf Zeilen außerdem die
/// Frage, um die es hier geht: *Wo landet das alles?*
///
/// **Kein eigener Bloc, wie bei der `SicherungsStandZeile`.** Es ist eine
/// nur-lesende Auskunft ohne Folgeschritt; ein zweiter Bloc neben dem
/// `KanzleiSettingsBloc` brächte Ereignis-, Zustands- und Registrierungscode
/// für einen einzigen Abruf. Neu geladen wird nach jedem Speichern der
/// Kanzleidaten: Der wirksame Ordner ändert sich genau dann, und ein
/// Übergangs-Listener ist hier das Richtige — gefragt ist die *Änderung*, nicht
/// der Stand beim Aufgehen (den holt [initState]).
class OrdnerZustandListe extends StatefulWidget {
  const OrdnerZustandListe({super.key});

  @override
  State<OrdnerZustandListe> createState() => OrdnerZustandListeState();
}

class OrdnerZustandListeState extends State<OrdnerZustandListe> {
  List<OrdnerZustand> _zustaende = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_laden());
  }

  /// Fehler bleiben stumm — genau wie bei der `SicherungsStandZeile`. Diese
  /// Auskunft ist Beiwerk neben den Feldern, die der Anwalt gerade ausfüllt;
  /// steht der Dienst nicht, ist eine leere Stelle die ehrlichere Antwort als
  /// eine Fehlermeldung über etwas, das er nicht angefasst hat.
  Future<void> _laden() async {
    var geladen = const <OrdnerZustand>[];
    try {
      final abruf = getIt<UseCase<List<OrdnerZustand>, NoParams>>();
      final ergebnis = await abruf(const NoParams());
      if (ergebnis case Right(value: final liste)) geladen = liste;
    } catch (_) {
      geladen = const [];
    }
    if (!mounted) return;
    setState(() => _zustaende = geladen);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KanzleiSettingsBloc, KanzleiSettingsState>(
      listenWhen: (_, neu) =>
          neu is KanzleiSettingsLoaded &&
          neu.gespeichert == KanzleiSettingsBereich.kanzlei,
      listener: (_, _) => unawaited(_laden()),
      child: _zeilen(context),
    );
  }

  Widget _zeilen(BuildContext context) {
    if (_zustaende.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        const Divider(height: 24),
        Text('Wohin die App ablegt', style: theme.textTheme.titleSmall),
        for (final zustand in _zustaende) OrdnerZustandZeile(zustand: zustand),
      ],
    );
  }
}
