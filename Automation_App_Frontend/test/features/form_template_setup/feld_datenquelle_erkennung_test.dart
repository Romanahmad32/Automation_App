import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein Test je Regel der Erkennung — die Reihenfolge der Regeln *ist* das
/// Verhalten, also gehört jede einzeln festgenagelt.
///
/// Die Fälle des abgeschafften `vorgangsdaten_field_matcher_test.dart` stehen
/// hier weiter: Sie sind die Regression gegen genau diese Zuordnung und dürfen
/// mit der Datei nicht verschwunden sein.
void main() {
  FeldDatenquelle quelle(String name) =>
      FeldDatenquelleErkennung.quelleFuer(name);

  group('Normalisierung', () {
    test('Schreibweise, Umlaute und Sonderzeichen sind egal', () {
      expect(
        FeldDatenquelleErkennung.normalisiere('Zahlungs-Frist'),
        'zahlungsfrist',
      );
      expect(
        FeldDatenquelleErkennung.normalisiere('ZAHLUNGSFRIST'),
        'zahlungsfrist',
      );
      expect(
        FeldDatenquelleErkennung.normalisiere('Straße des Geschädigten'),
        'strassedesgeschaedigten',
      );
    });
  });

  group('Mandantengruppe', () {
    test('erkennt die einzelnen Stammdaten', () {
      expect(quelle('Vorname des Mandanten'), FeldDatenquelle.mandantVorname);
      expect(quelle('Mandant Nachname'), FeldDatenquelle.mandantNachname);
      expect(quelle('Familienname Kunde'), FeldDatenquelle.mandantNachname);
      expect(
        quelle('Anrede des Mandanten'),
        FeldDatenquelle.mandantBriefanrede,
      );
      expect(quelle('Straße des Mandanten'), FeldDatenquelle.mandantStrasse);
      expect(quelle('PLZ Mandant'), FeldDatenquelle.mandantPlz);
      expect(quelle('Ort des Geschädigten'), FeldDatenquelle.mandantOrt);
      expect(quelle('E-Mail des Mandanten'), FeldDatenquelle.mandantEmail);
      expect(quelle('Telefon Mandant'), FeldDatenquelle.mandantTelefon);
      expect(
        quelle('Anschrift des Geschädigten'),
        FeldDatenquelle.mandantAnschrift,
      );
    });

    test('ein blosses Namensfeld meint den Anzeigenamen', () {
      expect(quelle('Name des Mandanten'), FeldDatenquelle.mandantName);
      expect(quelle('Geschädigter'), FeldDatenquelle.mandantName);
    });

    test('Kennzeichen des Mandanten ist nicht das des Gegners', () {
      // Der Kern der Verhaltensänderung: früher lieferte dieses Feld bewusst
      // nichts, weil es sonst an den Gegner-Matcher durchgefallen wäre.
      expect(quelle('Kennzeichen Mandant'), FeldDatenquelle.kennzeichenMandant);
      expect(
        quelle('Kennzeichen des Geschädigten'),
        FeldDatenquelle.kennzeichenMandant,
      );
    });
  });

  group('Vorgangs- und Unfalldaten', () {
    test('erkennt die Angaben, die bisher gar keine Entsprechung hatten', () {
      expect(quelle('Unfallort'), FeldDatenquelle.unfallort);
      expect(quelle('Unfalluhrzeit'), FeldDatenquelle.unfalluhrzeit);
      expect(quelle('Unfallzeit'), FeldDatenquelle.unfalluhrzeit);
      expect(
        quelle('Polizei-Vorgangsnummer'),
        FeldDatenquelle.polizeiVorgangsnummer,
      );
    });

    test('der Unfall geht dem Beteiligten vor', () {
      // Sonst fischt das „ort" der Mandantengruppe diese Namen ab und das
      // Schreiben trägt still den Wohnort statt des Unfallorts.
      expect(quelle('Unfallort des Geschädigten'), FeldDatenquelle.unfallort);
      expect(quelle('Unfalltag des Mandanten'), FeldDatenquelle.unfalldatum);
      expect(
        quelle('Polizei-Vorgangsnummer des Geschädigten'),
        FeldDatenquelle.polizeiVorgangsnummer,
      );
      // Die Gegenprobe: Ohne Unfallwort bleibt „Ort" der Wohnort.
      expect(quelle('Ort des Geschädigten'), FeldDatenquelle.mandantOrt);
    });

    test('erkennt Unfalldatum, Rechtsgebiet und Referenz', () {
      expect(quelle('Unfalldatum'), FeldDatenquelle.unfalldatum);
      expect(quelle('Unfalltag'), FeldDatenquelle.unfalldatum);
      expect(quelle('Schadentag'), FeldDatenquelle.unfalldatum);
      expect(quelle('Rechtsgebiet'), FeldDatenquelle.rechtsgebiet);
      expect(quelle('Sachgebiet'), FeldDatenquelle.rechtsgebiet);
      expect(quelle('Aktenzeichen'), FeldDatenquelle.referenz);
      expect(quelle('Referenz'), FeldDatenquelle.referenz);
    });

    test('„Zeichen" bindet nur allein stehend', () {
      expect(quelle('Zeichen'), FeldDatenquelle.referenz);
      // „Ihr Zeichen" meint das Aktenzeichen der Gegenseite, nicht das eigene.
      expect(quelle('Ihr Zeichen'), FeldDatenquelle.keine);
    });

    test('ein Kennzeichen ohne Mandantenbezug ist das des Gegners', () {
      expect(quelle('Kennzeichen'), FeldDatenquelle.kennzeichenGegner);
      expect(
        quelle('Kennzeichen des Unfallgegners'),
        FeldDatenquelle.kennzeichenGegner,
      );
    });
  });

  group('Versicherergruppe', () {
    test('erkennt Name, Adressteile und Kontaktwege', () {
      expect(
        quelle('Gegnerische Versicherung'),
        FeldDatenquelle.versichererName,
      );
      expect(
        quelle('Straße der Versicherung'),
        FeldDatenquelle.versichererStrasse,
      );
      expect(quelle('PLZ Versicherer'), FeldDatenquelle.versichererPlz);
      expect(quelle('Ort der Versicherung'), FeldDatenquelle.versichererOrt);
      expect(
        quelle('Anschrift der Versicherung'),
        FeldDatenquelle.versichererAnschrift,
      );
      expect(
        quelle('E-Mail der Versicherung'),
        FeldDatenquelle.versichererEmail,
      );
      expect(quelle('Fax Empfänger'), FeldDatenquelle.versichererFax);
    });

    test('Versicherungsschein und -beginn gehen dem Namen vor', () {
      expect(
        quelle('Versicherungsschein-Nr.'),
        FeldDatenquelle.versicherungsscheinNr,
      );
      expect(quelle('Schadennummer'), FeldDatenquelle.versicherungsscheinNr);
      expect(
        quelle('Versicherungsbeginn'),
        FeldDatenquelle.versicherungsbeginn,
      );
    });

    test('ein einzelnes E-Mail-Feld meint den Empfänger des Schreibens', () {
      expect(quelle('E-Mail'), FeldDatenquelle.versichererEmail);
    });
  });

  group('mehrdeutige Namen', () {
    test('„VersicherungPlzOrt" wird nicht gebunden und nennt den Grund', () {
      final vorschlag = FeldDatenquelleErkennung.erkenne('VersicherungPlzOrt');

      expect(vorschlag.quelle, FeldDatenquelle.keine);
      expect(vorschlag.hinweis, contains('PLZ und Ort'));
    });

    test(
      '„MandantVornameNachname" ebenfalls — die Reihenfolge wäre geraten',
      () {
        final vorschlag = FeldDatenquelleErkennung.erkenne(
          'MandantVornameNachname',
        );

        expect(vorschlag.quelle, FeldDatenquelle.keine);
        expect(vorschlag.hinweis, contains('Vorname und Nachname'));
      },
    );

    test('zusammengesetzte Quellen bleiben erlaubt', () {
      // „Anschrift" nennt kein einzelnes Stichwort und lässt fehlende Teile
      // weg — das können zwei Platzhalter nebeneinander nicht.
      expect(
        FeldDatenquelleErkennung.erkenne('Anschrift des Mandanten').hinweis,
        isNull,
      );
      // Straße und Hausnummer sind ein Feld, keine zwei Angaben.
      expect(
        FeldDatenquelleErkennung.erkenne('Straße und Hausnummer').hinweis,
        isNull,
      );
    });
  });

  group('Feldtyp', () {
    test('Datumsnamen entstehen als Datumsfeld', () {
      for (final name in ['Unfalldatum', 'Zahlungsfrist', 'Unfalltag']) {
        expect(
          FeldDatenquelleErkennung.erkenne(name).inputType,
          InputType.date,
          reason: name,
        );
      }
    });

    test('alles andere bleibt Textfeld', () {
      expect(
        FeldDatenquelleErkennung.erkenne('Betrag').inputType,
        InputType.text,
      );
      expect(
        FeldDatenquelleErkennung.erkenne('Auftrag').inputType,
        InputType.text,
      );
    });
  });

  group('kein Treffer', () {
    test('unbekannte Namen bleiben ungebunden statt geraten', () {
      expect(quelle('Notiz'), FeldDatenquelle.keine);
      expect(quelle('Schadenshöhe'), FeldDatenquelle.keine);
      expect(quelle(''), FeldDatenquelle.keine);
    });
  });

  group('neuesFeld', () {
    test('übernimmt Vorschlag für Datenquelle und Feldtyp', () {
      final feld = FeldDatenquelleErkennung.neuesFeld(
        order: 3,
        controlKey: 'field_3',
        platzhalter: 'Unfalldatum',
      );

      expect(feld.order, 3);
      // Bis zum Speichern trägt das Feld den Control-Schlüssel als Label.
      expect(feld.label, 'field_3');
      expect(feld.required, isFalse);
      expect(feld.inputType, InputType.date);
      expect(feld.datenquelle, FeldDatenquelle.unfalldatum);
    });

    test('ein von Hand angelegtes Feld bleibt leeres Textfeld', () {
      final feld = FeldDatenquelleErkennung.neuesFeld(
        order: 0,
        controlKey: 'field_0',
      );

      expect(feld.inputType, InputType.text);
      expect(feld.datenquelle, FeldDatenquelle.keine);
    });
  });
}
