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

  /// Wie lange nach dem letzten Tastendruck gewartet wird — voreingestellt
  /// [standardEntprellung].
  final Duration entprellung;

  final Widget child;

  /// Der Kompromiss zwischen „jeder Tastendruck ein Zustandswechsel" und „der
  /// letzte Halbsatz geht verloren".
  ///
  /// Waren zwei Sekunden, solange ein eigener Takt dahinter den Stand erst
  /// verzögert ablegte (#133). Seit die Meldung **selbst** die Sicherung
  /// auslöst, ist diese Dauer die einzige Verzögerung zwischen Tastendruck und
  /// abgelegtem Stand — und zwei Sekunden hießen: Wer schnell wegklickt,
  /// verliert den letzten Satz. 300 ms liegen über der Schlagfolge beim
  /// Tippen (ein geübter Schreiber bleibt darunter) und unter dem, was ein
  /// Mensch als Wartezeit bemerkt.
  static const standardEntprellung = Duration(milliseconds: 300);

  const FormWertBeobachter({
    super.key,
    required this.formGroup,
    required this.onWerteGeaendert,
    required this.child,
    this.entprellung = standardEntprellung,
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
    // Eine noch nicht entprellte Änderung ginge sonst verloren: Der Anwalt
    // tippt, verlässt binnen der Entprellung die Seite, und die letzten
    // Zeichen würden nie gemeldet. Deshalb hier nachholen, statt nichts zu
    // tun (§4.4, #133).
    final ausstehendeAenderung = _wartet?.isActive ?? false;
    _beende();
    if (ausstehendeAenderung) _melde();
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

  /// Meldet den aktuellen Formularwert — auch aus [dispose] heraus, seit
  /// #133: Frühere Annahme war, der Empfänger (meist ein Cubit) sei beim
  /// Verlassen der Seite bereits geschlossen und ein `emit` danach würfe.
  /// Das trifft die gängige Zusammensetzung nicht — der `BlocProvider` liegt
  /// über dem Formular und schließt seinen Cubit erst in seinem **eigenen**
  /// `dispose`, das Flutter erst **nach** dem der Kinder aufruft (Elemente
  /// bauen sich von den Blättern her ab). Diese Methode selbst braucht ohnehin
  /// weder `setState` noch den `BuildContext`: Sie liest nur [formGroup] und
  /// ruft den Callback auf, deshalb ist der Aufruf aus `dispose` unbedenklich.
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
