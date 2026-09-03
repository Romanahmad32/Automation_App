import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt die Schichten-Abhängigkeiten der Clean Architecture im Frontend.
///
/// Erlaubte Abhängigkeitsrichtung je Feature (`lib/features/<feature>/`):
///
///   presentation ──▶ domain ◀── data
///
/// * `domain` ist die innerste Schicht: keine Abhängigkeit auf `data` oder
///   `presentation` und frei von Flutter-UI-Frameworks (framework-unabhängig).
/// * `data` darf `domain` implementieren, aber nie auf `presentation` zugreifen.
/// * `presentation` greift ausschließlich über `domain` (Repository-Interfaces
///   und UseCases via DI) zu, nie direkt auf `data`.
///
/// Die Regeln gelten feature-übergreifend: ein Feature darf nicht auf die
/// `data`-/`presentation`-Interna eines anderen Features zugreifen.
void main() {
  final dateien = dartQuelldateien('lib');

  // Trifft einen internen Import in eine bestimmte Schicht – egal welches
  // Feature (z. B. import '.../features/mailbox/data/...').
  RegExp importInSchicht(String schicht) =>
      RegExp("import\\s+'package:automation_app/features/[a-z0-9_]+/$schicht/");

  final importsData = importInSchicht('data');
  final importsPresentation = importInSchicht('presentation');
  final importsFlutterUi = RegExp(
    "import\\s+'package:flutter/(material|widgets|cupertino)\\.dart'",
  );
  final importsDio = RegExp("import\\s+'package:dio/dio\\.dart'");

  Iterable<File> dateienInSchicht(String schicht) => dateien.where((f) {
    final p = relPfad(f);
    return p.contains('/features/') && p.contains('/$schicht/');
  });

  void erwarteKeineTreffer(
    String beschreibung,
    Iterable<File> kandidaten,
    RegExp verboten,
  ) {
    final verstoesse = <String>[
      for (final f in kandidaten)
        if (verboten.hasMatch(f.readAsStringSync())) relPfad(f),
    ]..sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          '$beschreibung\nVerletzende Dateien:\n  '
          '${verstoesse.join('\n  ')}',
    );
  }

  group('Clean-Architecture-Schichtenregeln', () {
    test('domain hängt weder von data noch von presentation ab', () {
      final domain = dateienInSchicht('domain');
      erwarteKeineTreffer(
        'Die domain-Schicht darf nicht von der data-Schicht abhängen.',
        domain,
        importsData,
      );
      erwarteKeineTreffer(
        'Die domain-Schicht darf nicht von der presentation-Schicht abhängen.',
        domain,
        importsPresentation,
      );
    });

    test('domain ist frei von Flutter-UI-Abhängigkeiten', () {
      erwarteKeineTreffer(
        'Die domain-Schicht muss framework-unabhängig bleiben '
        '(kein Import von flutter material/widgets/cupertino).',
        dateienInSchicht('domain'),
        importsFlutterUi,
      );
    });

    test('data hängt nicht von presentation ab', () {
      erwarteKeineTreffer(
        'Die data-Schicht darf nicht von der presentation-Schicht abhängen.',
        dateienInSchicht('data'),
        importsPresentation,
      );
    });

    test('presentation greift nicht direkt auf data zu', () {
      erwarteKeineTreffer(
        'Die presentation-Schicht darf nicht direkt auf die data-Schicht '
        'zugreifen, sondern nur über die domain-Schicht '
        '(Repository-Interface/UseCase + DI).',
        dateienInSchicht('presentation'),
        importsData,
      );
    });

    test('presentation spricht kein HTTP direkt', () {
      // dart:io ist hier bewusst nicht mitgeprüft: mehrere Features öffnen
      // oder speichern lokale Dateien direkt aus der Präsentation (native
      // Dialoge, Anhänge) — ein etabliertes, nicht zu beanstandendes Muster.
      // Diese Regel trifft gezielt den Schichtbruch, der Anlass für sie war:
      // Dio (HTTP) gehört ausschließlich in die data-Schicht.
      erwarteKeineTreffer(
        'Die presentation-Schicht darf Dio nicht importieren — HTTP-Zugriff '
        'gehört in die data-Schicht (Datasource/Repository), die Präsentation '
        'bekommt nur noch Domain-Typen bzw. Either<Failure, T>.',
        dateienInSchicht('presentation'),
        importsDio,
      );
    });
  });
}
