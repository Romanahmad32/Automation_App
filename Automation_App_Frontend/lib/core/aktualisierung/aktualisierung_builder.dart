import 'dart:async';

import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/aktualisierung/aktualisierungs_pruefer.dart';
import 'package:automation_app/core/backend/app_version.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:flutter/material.dart';

/// Führt die Update-Prüfung einmal aus und stellt das Ergebnis zum Bauen bereit.
///
/// Bewusst ein Widget und kein Bloc: es gibt keinen Zustand, den jemand ändern
/// könnte, keine Ereignisse und nichts zu speichern — nur eine Frage, die
/// einmal gestellt wird. Ein Bloc dafür wäre drei Dateien Aufwand ohne Gewinn.
///
/// Solange die Antwort aussteht, ist [AktualisierungsErgebnis] `null`. Die
/// Oberfläche zeigt dann einfach noch keinen Hinweis; ein Ladeindikator wäre
/// hier Lärm.
class AktualisierungBuilder extends StatefulWidget {
  const AktualisierungBuilder({
    required this.builder,
    this.pruefer = const AktualisierungsPruefer(),
    super.key,
  });

  final Widget Function(BuildContext context, AktualisierungsErgebnis? stand)
  builder;

  final AktualisierungsPruefer pruefer;

  @override
  State<AktualisierungBuilder> createState() => _AktualisierungBuilderState();
}

class _AktualisierungBuilderState extends State<AktualisierungBuilder> {
  AktualisierungsErgebnis? _stand;

  @override
  void initState() {
    super.initState();
    unawaited(_pruefen());
  }

  Future<void> _pruefen() async {
    // Ohne registrierte Version (Widget-Tests) gibt es nichts zu vergleichen.
    if (!getIt.isRegistered<AppVersion>()) return;
    final laufend = getIt<AppVersion>().anzeige;

    final stand = await widget.pruefer.pruefen(laufend);
    if (!mounted) return;
    setState(() => _stand = stand);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _stand);
}
