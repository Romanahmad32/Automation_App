import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_json.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_rueckfluss.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der angefangene Ausfüllstand am Vorgang (#37, Teil 2): eigenes Feld neben
/// den bestätigten `feldWerte`, verlustfrei über den HTTP-Vertrag, und mit der
/// einen Eigenschaft, die die übrigen Vorgangsfelder nicht haben — er muss sich
/// **löschen** lassen.
void main() {
  final entwurf = VorgangEntwurf(
    gespeichertAm: DateTime(2026, 8, 30, 14, 32),
    feldWerte: const {'Versicherer': 'HUK-COBURG'},
    schadensaufstellung: const DamageListing(
      items: [DamageItem(description: 'Reparaturkosten', amount: 1250.5)],
    ),
  );

  final vorgang = Vorgang.ausAnfrage(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 6, 1),
  );

  test('überlebt den Weg durch JSON', () {
    final zurueck = VorgangEntwurf.fromJson(entwurf.toJson());

    expect(zurueck, entwurf);
    expect(zurueck.schadensaufstellung?.items.single.amount, 1250.5);
  });

  test('reist im Vorgang mit', () {
    final mitEntwurf = vorgang.copyWith(entwurf: () => entwurf);

    final zurueck = vorgangAusJson(mitEntwurf.toJson());

    expect(zurueck.entwurf, entwurf);
  });

  /// Die übrigen `copyWith`-Parameter folgen dem Muster „null heißt:
  /// unverändert" und können deshalb nichts löschen. Beim Entwurf ist Löschen
  /// die halbe Funktion — „Verwerfen" muss ankommen.
  test('lässt sich über copyWith wieder löschen', () {
    final mitEntwurf = vorgang.copyWith(entwurf: () => entwurf);

    expect(mitEntwurf.copyWith(entwurf: () => null).entwurf, isNull);
    // Kein Argument heißt weiterhin: unverändert.
    expect(mitEntwurf.copyWith(gegner: 'HUK').entwurf, entwurf);
  });

  test('ein leerer Entwurf ist keiner', () {
    expect(
      VorgangEntwurf(
        gespeichertAm: DateTime(2026, 8, 30),
        feldWerte: const {'Versicherer': '  '},
      ).istLeer,
      isTrue,
    );
    expect(entwurf.istLeer, isFalse);
  });

  /// „Ein bestätigter Stand gewinnt gegen einen älteren Entwurf" — hier ist der
  /// Entwurf nicht älter, sondern erledigt: Aus genau diesen Werten ist gerade
  /// ein Dokument entstanden.
  test('der Rückfluss verdrängt den Entwurf', () {
    final mitEntwurf = vorgang.copyWith(entwurf: () => entwurf);

    final bestaetigt = VorgangRueckfluss.uebernehmeWizardErgebnis(
      mitEntwurf,
      fields: const [
        FieldData(
          order: 0,
          label: 'Unfallort',
          required: true,
          inputType: InputType.text,
          datenquelle: FeldDatenquelle.unfallort,
        ),
      ],
      formData: const {'Unfallort': 'Bad Homburg'},
    );

    expect(bestaetigt.entwurf, isNull);
    expect(bestaetigt.feldWerte, {'Unfallort': 'Bad Homburg'});
    expect(bestaetigt.unfallort, 'Bad Homburg');
  });
}
