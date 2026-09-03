import 'dart:io';

import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Ausschlussliste der app-eigenen Platzhalter (#35 Teil 1): Was die App
/// beim Erzeugen selbst füllt, darf nie Eingabefeld oder Pflicht werden.
void main() {
  test('erkennt jeden app-eigenen Namen', () {
    for (final name in AppEigenePlatzhalter.namen) {
      expect(
        AppEigenePlatzhalter.istAppEigen(name),
        isTrue,
        reason: '$name füllt die App selbst',
      );
    }
  });

  test('vergleicht ohne Groß-/Kleinschreibung — wie die Backend-Ersetzung', () {
    expect(AppEigenePlatzhalter.istAppEigen('schadensaufstellung'), isTrue);
    expect(AppEigenePlatzhalter.istAppEigen('RVGNETTO'), isTrue);
    expect(AppEigenePlatzhalter.istAppEigen('  Gegenstandswert  '), isTrue);
  });

  test('gewöhnliche Feldnamen bleiben übernehmbar', () {
    expect(AppEigenePlatzhalter.istAppEigen('Kennzeichen'), isFalse);
    expect(AppEigenePlatzhalter.istAppEigen('Unfalldatum'), isFalse);
  });

  /// Die Liste hier ist eine Spiegelung: Gefüllt wird im Backend, und die
  /// beiden Seiten sind nur über Zeichenketten verbunden. Ein neuer Name, der
  /// dort dazukommt und hier fehlt, wird in der App als Eingabefeld angeboten
  /// — der Anwalt tippt einen Wert, den das Dokument gleich wieder
  /// überschreibt. Umgekehrt verschwiege die App ein Feld, das niemand füllt.
  ///
  /// Geprüft wird gegen die Quelle, nicht gegen eine zweite Aufzählung: Sonst
  /// gäbe es drei Listen statt zwei.
  test('deckt sich mit den Namen im Backend', () {
    final rvg = File(
      '../AutomationService/AutomationService/Features/'
      'WordAutomation/Domain/Services/RvgPlatzhalter.cs',
    );
    final tabelle = File(
      '../AutomationService/AutomationService/Features/'
      'WordAutomation/Domain/Services/DamageListingTable.cs',
    );
    if (!rvg.existsSync() || !tabelle.existsSync()) {
      fail(
        'Die Backend-Quellen wurden nicht gefunden. Dieser Test läuft aus dem '
        'Paket-Stammverzeichnis (Automation_App_Frontend) im vollen Klon.',
      );
    }

    // `public const string Gegenstandswert = "Gegenstandswert";`
    final konstante = RegExp(r'public const string \w+ = "([^"]+)";');
    final ausBackend = {
      for (final treffer in konstante.allMatches(rvg.readAsStringSync()))
        treffer.group(1)!,
      // Die Tabelle trägt ihren Namen mit Klammern, weil sie danach im
      // Absatztext sucht.
      ...konstante
          .allMatches(tabelle.readAsStringSync())
          .map((treffer) => treffer.group(1)!.replaceAll(RegExp(r'[{}]'), '')),
    };

    expect(
      AppEigenePlatzhalter.namen,
      ausBackend,
      reason:
          'Ein app-eigener Platzhalter gehört an beide Stellen: '
          'RvgPlatzhalter.cs im Backend und AppEigenePlatzhalter hier.',
    );
  });

  test('jeder Eintrag erklärt sich und zeigt ein Beispiel', () {
    for (final eintrag in AppEigenePlatzhalter.eintraege) {
      expect(eintrag.erklaerung, isNotEmpty, reason: eintrag.name);
      expect(eintrag.beispiel, isNotEmpty, reason: eintrag.name);
    }
  });

  test('nur exakte Namen zählen — was das Backend nicht ersetzt, '
      'ist nicht app-eigen', () {
    // {{Rvg-Netto}} bliebe im Dokument stehen; der Anwalt muss so ein Feld
    // weiter anlegen dürfen (bzw. die Warnung „Platzhalter ohne Feld" sehen).
    expect(AppEigenePlatzhalter.istAppEigen('Rvg-Netto'), isFalse);
    expect(AppEigenePlatzhalter.istAppEigen('Rvg Netto'), isFalse);
  });
}
