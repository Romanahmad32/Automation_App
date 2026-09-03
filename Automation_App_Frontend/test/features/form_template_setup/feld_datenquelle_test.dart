import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die zwei Zusagen von [FeldDatenquelle], deren Bruch niemandem auffiele —
/// deshalb stehen sie hier.
///
/// **Der Persistenzschluessel.** `FieldData` speichert eine Datenquelle als
/// Zeichenkette (`datenquelle: quelle.value`) und liest sie ueber
/// `FeldDatenquelle.fromValue` zurueck. Faellt der Schluessel weg, liefert
/// `fromValue` still [FeldDatenquelle.keine]: kein Fehler, keine Meldung, nur
/// eine Vorlage, deren Feld ab sofort leer bleibt. Auffallen wuerde das erst am
/// fehlenden Wert im naechsten Schreiben. Genau dieser Fall lag beim Umbenennen
/// von „Aktenzeichen" auf „Zeichen" (§4.2) offen: Der Anzeigename wechselte,
/// der gespeicherte Wert durfte es nicht. Statt den alten Wert kommentarlos
/// stehen zu lassen — was wie ein vergessenes Aufraeumen aussieht und beim
/// naechsten Mal genau so behandelt wuerde — traegt die Quelle ihn als
/// `frueher`, und dieser Test haelt beide Wege.
///
/// **Der Rundlauf des Platzhalterkatalogs (§4.7, §5.3).** Bis zum 02.09.2026
/// fuehrte nur ein Weg vom Namen zur Datenquelle, und die im Vorlageneditor
/// angebotene Liste war handgeschrieben — mit dem Eingestaendnis im Code, dass
/// sie „stillschweigend veraltet". Seit `FeldDatenquelle.platzhalter` wird sie
/// **abgeleitet**, und dann muss jeder angebotene Name ueber
/// `FeldDatenquelleErkennung` wieder auf **genau denselben** Eintrag
/// zurueckfuehren. Ohne diese Pruefung waere der Katalog ein Versprechen ohne
/// Deckung: Der Anwalt waehlt „Versicherer · Ort" und bekommt den Namen der
/// Versicherung.
void main() {
  group('fromValue', () {
    test('liest den aktuellen Schlüssel', () {
      expect(FeldDatenquelle.fromValue('zeichen'), FeldDatenquelle.zeichen);
    });

    test('liest den früheren Schlüssel bestehender Vorlagen', () {
      // Die beiden angelegten Kanzleivorlagen tragen diesen Wert in der
      // Datenbank. Wer ihn aus der Quelle entfernt, nimmt ihnen die Zuordnung.
      expect(
        FeldDatenquelle.fromValue('aktenzeichen'),
        FeldDatenquelle.zeichen,
      );
    });

    test('unbekannte und fehlende Werte bleiben ungebunden', () {
      expect(FeldDatenquelle.fromValue('gibtesnicht'), FeldDatenquelle.keine);
      expect(FeldDatenquelle.fromValue(null), FeldDatenquelle.keine);
      expect(FeldDatenquelle.fromValue(''), FeldDatenquelle.keine);
    });

    test('jede Quelle findet über ihren eigenen value zurück', () {
      for (final quelle in FeldDatenquelle.values) {
        expect(
          FeldDatenquelle.fromValue(quelle.value),
          quelle,
          reason: 'Der Schlüssel „${quelle.value}" führt nicht zu $quelle.',
        );
      }
    });
  });

  test('kein Schlüssel kommt zweimal vor', () {
    // Ein doppelter Wert — auch zwischen `value` und einem `frueher` einer
    // anderen Quelle — macht `fromValue` von der Aufzählungsreihenfolge
    // abhängig: Dieselbe gespeicherte Vorlage läse sich dann je nach Position
    // im Enum anders.
    final gesehen = <String, FeldDatenquelle>{};
    for (final quelle in FeldDatenquelle.values) {
      for (final schluessel in [quelle.value, quelle.frueher]) {
        if (schluessel == null) continue;
        expect(
          gesehen.containsKey(schluessel),
          isFalse,
          reason:
              'Der Schlüssel „$schluessel" gehört schon zu '
              '${gesehen[schluessel]} und nun auch zu $quelle.',
        );
        gesehen[schluessel] = quelle;
      }
    }
  });

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
    // Diese Quelle ist über einen Namen **nicht** erreichbar — ein Mangel im
    // Bestand, der erst durch die Auswahl sichtbar wurde. Sie steht hier
    // namentlich, damit die Lücke benannt bleibt statt als vergessener Eintrag
    // durchzugehen; die Begründung steht am Katalogeintrag.
    //
    // Vormals stand hier auch `zeichen`: Beide Namen dafür trafen die volle
    // Referenz (Restposten aus #38). Seit §4.2 treffen sie die kurze Form, und
    // damit ist die Quelle erreichbar und wird angeboten — der Fall gehört
    // jetzt in die Gruppe darüber.
    test('Versicherer · Adresse — „adresse" trifft die Anschrift', () {
      expect(FeldDatenquelle.versichererAdresse.istWaehlbar, isFalse);
      expect(
        FeldDatenquelleErkennung.quelleFuer('VersichererAdresse'),
        FeldDatenquelle.versichererAnschrift,
      );
    });
  });

  group('Bestandsschutz der Namen, die schon in Vorlagen stehen', () {
    test('{{Aktenzeichen}} bleibt die kurze Form (§4.2)', () {
      // Der alte Name steht in den beiden angelegten Kanzleivorlagen. Er muss
      // dasselbe treffen wie „Zeichen" — die volle Referenz bekommt nur, wer
      // sie ausdrücklich anfordert.
      expect(
        FeldDatenquelleErkennung.quelleFuer('Aktenzeichen'),
        FeldDatenquelle.zeichen,
      );
      expect(
        FeldDatenquelleErkennung.quelleFuer('Referenz'),
        FeldDatenquelle.referenz,
      );
    });

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
