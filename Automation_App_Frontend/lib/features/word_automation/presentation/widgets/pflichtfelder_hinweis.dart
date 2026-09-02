import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Warum der Absenden-Knopf gesperrt ist: „2 Pflichtfelder fehlen:
/// Unfalldatum, Versicherer" — jeder Name anklickbar und springt (per Fokus)
/// in sein Feld (#35 Teil 3). Vorher war der Knopf einfach tot, ohne zu
/// sagen, welches Feld ihn sperrt.
///
/// Gezeigt als [FehlerHinweis], wie jede andere Beanstandung der App: Symbol
/// in der Fehlerfarbe, Text daneben, über die ganze Breite. Die Schwester
/// `SchadenspositionFehlerliste` sitzt im nächsten Schritt über demselben
/// Knopf und tut dasselbe — vorher stand hier stattdessen eine kleingesetzte,
/// mittig schwebende Zeile ohne Symbol.
class PflichtfelderHinweis extends StatelessWidget {
  /// Die Feldnamen, die im aktuellen Formular als Pflicht gelten (nach der
  /// Ableitung je Vorlagenvariante, #35 Teil 2).
  final List<String> pflichtFelder;

  const PflichtfelderHinweis({super.key, required this.pflichtFelder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        // Nur die leer gebliebenen Pflichtfelder — ein falsch formatiertes
        // Datum meldet sein Feld selbst und gehört nicht in diese Zeile.
        final fehlend = [
          for (final name in pflichtFelder)
            if (formGroup.control(name).hasError(ValidationMessage.required))
              name,
        ];
        if (fehlend.isEmpty) return const SizedBox.shrink();

        return FehlerHinweis(
          nachricht: fehlend.length == 1
              ? '1 Pflichtfeld fehlt:'
              : '${fehlend.length} Pflichtfelder fehlen:',
          inhalt: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in fehlend)
                InkWell(
                  onTap: () => formGroup.control(name).focus(),
                  child: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
