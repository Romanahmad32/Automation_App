import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Meldet den laufenden Tippstand einer [FormGroup] nach außen — entprellt,
/// damit nicht jeder Tastendruck einen Zustandswechsel auslöst.
///
/// Gedacht für Formulare, deren Eingaben einen Neuaufbau überleben sollen. Wer
/// die Werte erst beim Absenden erfährt, verliert alles, was vorher passiert:
/// wird die Vorlage nebenan bearbeitet und die Liste neu geladen, baut das
/// Formular sich neu auf und startet leer. Ein [BlocListener] hilft dagegen
/// nicht — die Werte liegen in den FormControls, nicht im Bloc.
///
/// Der gemeldete Stand ist **unbestätigt**: Er taugt zum Wiedereinsetzen, aber
/// nicht als Voraussetzung für Folgeschritte (dafür bleibt das Absenden
/// zuständig).
class FormWertBeobachter extends StatefulWidget {
  final FormGroup formGroup;

  /// Bekommt den vollständigen Stand (Feldname → Wert), auch die leeren Felder.
  final ValueChanged<Map<String, String>> onWerteGeaendert;

  /// Wie lange nach dem letzten Tastendruck gewartet wird. Zwei Sekunden sind
  /// der Kompromiss: kurz genug, dass ein Neuaufbau selten mehr als den letzten
  /// Halbsatz kostet, lang genug, dass Tippen keine Zustandswechsel-Lawine
  /// auslöst.
  final Duration entprellung;

  final Widget child;

  const FormWertBeobachter({
    super.key,
    required this.formGroup,
    required this.onWerteGeaendert,
    required this.child,
    this.entprellung = const Duration(seconds: 2),
  });

  @override
  State<FormWertBeobachter> createState() => _FormWertBeobachterState();
}

class _FormWertBeobachterState extends State<FormWertBeobachter> {
  StreamSubscription<Object?>? _abo;
  Timer? _wartet;

  @override
  void initState() {
    super.initState();
    _abonniere();
  }

  @override
  void didUpdateWidget(FormWertBeobachter alt) {
    super.didUpdateWidget(alt);
    // Nach einem Neuaufbau des Formulars steht hier eine andere FormGroup; das
    // Abo hinge sonst an der alten und meldete nie wieder etwas.
    if (!identical(alt.formGroup, widget.formGroup)) {
      _beende();
      _abonniere();
    }
  }

  @override
  void dispose() {
    _beende();
    super.dispose();
  }

  void _abonniere() {
    _abo = widget.formGroup.valueChanges.listen((_) {
      _wartet?.cancel();
      _wartet = Timer(widget.entprellung, _melde);
    });
  }

  void _beende() {
    _abo?.cancel();
    _abo = null;
    _wartet?.cancel();
    _wartet = null;
  }

  /// Bewusst **kein** Melden aus [dispose] heraus: Beim Verlassen der Seite
  /// wird auch der Empfänger (Cubit) geschlossen, und ein `emit` danach wirft.
  /// Was in den letzten zwei Sekunden getippt wurde, überlebt den
  /// Seitenwechsel deshalb nicht — dafür braucht es die Ablage am Vorgang.
  void _melde() {
    if (!mounted) return;
    widget.onWerteGeaendert(
      widget.formGroup.value.map(
        (feld, wert) => MapEntry(feld, wert?.toString() ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
