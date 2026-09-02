import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der **Rundlauf** des Platzhalterkatalogs (§4.7, §5.3).
///
/// Der Fall, der diese Datei trägt: Bis zum 02.09.2026 führte nur ein Weg vom
/// Namen zur Datenquelle, und die im Vorlageneditor angebotene Liste war
/// handgeschrieben — mit dem Eingeständnis im Code, dass sie „stillschweigend
/// veraltet". Seit `FeldDatenquelle.platzhalter` wird die Liste **abgeleitet**,
/// und dieser Test hält beide Richtungen zusammen:
///
/// > Jeder angebotene Name muss über `FeldDatenquelleErkennung` wieder auf
/// > **genau denselben** Eintrag zurückführen.
///
/// Ohne ihn wäre der Katalog ein Versprechen ohne Deckung: Der Anwalt wählt
/// „Versicherer · Ort" und bekommt den Namen der Versicherung.
void main() {
  group('jeder angebotene Platzhalter führt auf seine Quelle zurück', () {
    for (final quelle in FeldDatenquelle.waehlbare) {
      test('${quelle.geschrieben} → ${quelle.value}', () {
        expect(
          FeldDatenquelleErkennung.quelleFuer(quelle.platzhalter),
          quelle,
          reason:
              'Der angebotene Name löst auf eine andere Quelle auf. Entweder '
              'ist der Name in FeldDatenquelle.platzhalter falsch gewählt, '
              'oder die Prüfreihenfolge in FeldDatenquelleErkennung fischt '
              'ihn vorher ab.',
        );
      });
    }
  });

  test('kein angebotener Name gilt als mehrdeutig', () {
    // `erkenne` gibt bei zwei Angaben in einem Namen bewusst `keine` zurück
    // („PlzOrt"). Ein angebotener Name, der darin hängen bliebe, wäre ein
    // Eintrag, den die Auswahl anbietet und die Ersetzung verwirft.
    final mehrdeutig = FeldDatenquelle.waehlbare
        .where(
          (quelle) =>
              FeldDatenquelleErkennung.erkenne(quelle.platzhalter).hinweis !=
              null,
        )
        .map((quelle) => quelle.geschrieben)
        .toList();

    expect(mehrdeutig, isEmpty);
  });

  test('jeder Platzhaltername kommt nur einmal vor', () {
    final namen = FeldDatenquelle.waehlbare
        .map(
          (quelle) => FeldDatenquelleErkennung.normalisiere(quelle.platzhalter),
        )
        .toList();

    expect(
      namen.toSet().length,
      namen.length,
      reason:
          'Zwei Quellen unter demselben Namen könnte niemand auseinander '
          'halten — und eine davon wäre unerreichbar.',
    );
  });

  test('jede Quelle außer „keine" gehört in eine Gruppe', () {
    final ohneGruppe = FeldDatenquelle.values
        .where(
          (quelle) =>
              quelle.istGesetzt && quelle.gruppe == PlatzhalterGruppe.ohne,
        )
        .map((quelle) => quelle.value)
        .toList();

    expect(
      ohneGruppe,
      isEmpty,
      reason: 'Ohne Gruppe erscheint der Eintrag in keiner Auswahl.',
    );
  });

  group('was bewusst nicht angeboten wird', () {
    // Diese zwei Quellen sind über einen Namen **nicht** erreichbar — ein
    // Mangel im Bestand, der erst durch die Auswahl sichtbar wurde. Sie stehen
    // hier namentlich, damit die Lücke benannt bleibt statt als vergessener
    // Eintrag durchzugehen; die Begründung steht am Katalogeintrag.
    test('Versicherer · Adresse — „adresse" trifft die Anschrift', () {
      expect(FeldDatenquelle.versichererAdresse.istWaehlbar, isFalse);
      expect(
        FeldDatenquelleErkennung.quelleFuer('VersichererAdresse'),
        FeldDatenquelle.versichererAnschrift,
      );
    });

    test('Aktenzeichen — „aktenzeichen" trifft die volle Referenz (#38)', () {
      expect(FeldDatenquelle.aktenzeichen.istWaehlbar, isFalse);
      expect(
        FeldDatenquelleErkennung.quelleFuer('Aktenzeichen'),
        FeldDatenquelle.referenz,
      );
      expect(
        FeldDatenquelleErkennung.quelleFuer('Zeichen'),
        FeldDatenquelle.referenz,
      );
    });
  });

  group('Bestandsschutz der Namen, die schon in Vorlagen stehen', () {
    test('blankes {{Kennzeichen}} bleibt das des Gegners (#58)', () {
      expect(
        FeldDatenquelleErkennung.quelleFuer('Kennzeichen'),
        FeldDatenquelle.kennzeichenGegner,
      );
    });

    test('{{Mandant Kennzeichen}} bleibt davon unberührt', () {
      expect(
        FeldDatenquelleErkennung.quelleFuer('Mandant Kennzeichen'),
        FeldDatenquelle.kennzeichenMandant,
      );
    });

    test('{{Schadennummer}} bleibt die Versicherungsschein-Nr.', () {
      expect(
        FeldDatenquelleErkennung.quelleFuer('Schadennummer'),
        FeldDatenquelle.versicherungsscheinNr,
      );
    });
  });
}
