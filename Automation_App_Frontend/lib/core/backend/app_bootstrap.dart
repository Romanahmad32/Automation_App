import 'dart:async';

import 'package:automation_app/core/backend/backend_launcher.dart';
import 'package:automation_app/core/backend/backend_start_fehler_screen.dart';
import 'package:automation_app/core/backend/backend_start_screen.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:flutter/material.dart';

/// Startvorgang der Anwendung: erst den lokalen Dienst, dann die Dependency
/// Injection, dann die Oberfläche.
///
/// Bewusst als Widget und nicht als `await` vor `runApp`: sonst stünde während
/// des Dienststarts ein leeres Fenster da. So sieht der Anwender ab der ersten
/// Sekunde, dass etwas passiert — und im Fehlerfall, was.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.anwendungBauen, super.key});

  /// Baut die eigentliche Anwendung, sobald alles steht. Als Callback, damit
  /// dieser Startvorgang die Anwendung nicht kennen muss.
  final Widget Function() anwendungBauen;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  String? _fehler;
  bool _bereit = false;

  /// get_it verträgt keine doppelte Registrierung. Nach einem fehlgeschlagenen
  /// Versuch darf die DI beim „Erneut versuchen" also nicht noch einmal laufen.
  bool _diFertig = false;

  @override
  void initState() {
    super.initState();
    unawaited(_starten());
  }

  Future<void> _starten() async {
    final ergebnis = await BackendLauncher().starten();
    if (!mounted) return;

    if (!ergebnis.erfolgreich) {
      setState(() => _fehler = ergebnis.meldung ?? 'Unbekannter Fehler.');
      return;
    }

    if (!_diFertig) {
      await configureDependencies();
      await getIt.allReady();
      _diFertig = true;
    }
    if (!mounted) return;
    setState(() => _bereit = true);
  }

  void _erneutVersuchen() {
    setState(() => _fehler = null);
    unawaited(_starten());
  }

  @override
  Widget build(BuildContext context) {
    final fehler = _fehler;
    if (fehler != null) {
      return BackendStartFehlerScreen(
        meldung: fehler,
        onErneutVersuchen: _erneutVersuchen,
      );
    }
    if (!_bereit) return const BackendStartScreen();
    return widget.anwendungBauen();
  }
}
