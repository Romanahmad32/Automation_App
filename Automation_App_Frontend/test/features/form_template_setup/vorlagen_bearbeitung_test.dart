import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der veränderliche Stand des Vorlageneditors (#104) — ohne Tester und ohne
/// Bloc prüfbar, genau dafür wurde er aus der Detailseite herausgezogen.
///
/// Geprüft wird, was die Seite bisher in ihrem `State` tat und wobei ihr
/// niemand zusah: Schlüsselvergabe, Reihenfolge, Dateien und „Alle
/// übernehmen".
void main() {
  const vorlage = FormTemplate(
    id: 7,
    templateName: 'Anspruchsschreiben',
    fields: [
      FieldData(
        order: 0,
        label: 'Kennzeichen',
        required: true,
        inputType: InputType.text,
      ),
      FieldData(
        order: 1,
        label: 'Unfalldatum',
        required: false,
        inputType: InputType.date,
      ),
    ],
    wordFilePathOhneAuflistung: 'HGN.docx',
  );

  TemplatePlaceholdersState zustandMit({
    List<String>? ohne,
    List<String>? mit,
  }) {
    var zustand = const TemplatePlaceholdersState();
    if (ohne != null) {
      zustand = zustand.withSlot(
        TemplateFileSlot.ohneAuflistung,
        SlotPlaceholdersLoaded(ohne),
      );
    }
    if (mit != null) {
      zustand = zustand.withSlot(
        TemplateFileSlot.mitAuflistung,
        SlotPlaceholdersLoaded(mit),
      );
    }
    return zustand;
  }

  group('Ausgangsstand', () {
    test('eine bestehende Vorlage kommt mit Controls und Pfad herein', () {
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);

      // Solange die Seite offen ist, hält `label` den Control-Schlüssel und
      // der Name steht im Control (siehe FALLSTRICKE.md).
      expect(bearbeitung.fields.map((f) => f.label), ['field_0', 'field_1']);
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Unfalldatum']);
      expect(bearbeitung.nextFieldIndex, 2);
      expect(bearbeitung.pfadOhneAuflistung, 'HGN.docx');
      expect(bearbeitung.pfadMitAuflistung, isNull);
    });

    test('ohne Vorlage ist alles leer', () {
      final bearbeitung = VorlagenBearbeitung.fuer(null);

      expect(bearbeitung.fields, isEmpty);
      expect(bearbeitung.nextFieldIndex, 0);
      expect(bearbeitung.pfad(TemplateFileSlot.ohneAuflistung), isNull);
      expect(bearbeitung.pfad(TemplateFileSlot.mitAuflistung), isNull);
    });
  });

  group('Felder anlegen', () {
    test('jedes neue Feld bekommt einen fortlaufenden Schlüssel und sein '
        'Control', () {
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);

      bearbeitung.feldHinzufuegen(name: 'Frist');
      bearbeitung.feldHinzufuegen(name: 'Zeichen', pflicht: true);

      expect(bearbeitung.fields.map((f) => f.label), [
        'field_0',
        'field_1',
        'field_2',
        'field_3',
      ]);
      expect(bearbeitung.nextFieldIndex, 4);
      expect(bearbeitung.feldnamen, [
        'Kennzeichen',
        'Unfalldatum',
        'Frist',
        'Zeichen',
      ]);
      expect(bearbeitung.fields.map((f) => f.order), [0, 1, 2, 3]);
      expect(bearbeitung.fields.last.required, isTrue);
      // Der Feldtyp wird aus dem Namen **vorgeschlagen** (§1.3): „Frist" ist
      // ein Datum, „Zeichen" nicht.
      expect(bearbeitung.fields[2].inputType, InputType.date);
      expect(bearbeitung.fields[3].inputType, InputType.text);
    });

    test('ein gelöschter Schlüssel wird nicht wiederverwendet', () {
      // Sonst zeigten zwei Felder nacheinander auf dasselbe Control, und das
      // zweite trüge den Namen des ersten.
      final bearbeitung = VorlagenBearbeitung.fuer(null);
      bearbeitung.feldHinzufuegen(name: 'Frist');
      bearbeitung.formGroup.removeControl('field_0');
      bearbeitung.fields.removeAt(0);

      bearbeitung.feldHinzufuegen(name: 'Zeichen');

      expect(bearbeitung.fields.single.label, 'field_1');
      expect(bearbeitung.feldnamen, ['Zeichen']);
    });

    test('„Alle übernehmen" legt zu jedem Namen ein Pflichtfeld an', () {
      final bearbeitung = VorlagenBearbeitung.fuer(null);

      bearbeitung.alleUebernehmen(['Frist', 'Zeichen']);

      expect(bearbeitung.feldnamen, ['Frist', 'Zeichen']);
      expect(bearbeitung.fields.every((f) => f.required), isTrue);
    });

    test(
      '„Alle übernehmen" auf dem Stand der Karte erzeugt keine Doppelten',
      () {
        // Die Karte liefert `VorlagenStand.platzhalterOhneFeld` — bereits
        // entdoppelt und ohne die schon vorhandenen. Das ist der Grund, warum
        // hier nicht noch einmal gefiltert wird.
        final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
        bearbeitung.setzePfad(
          TemplateFileSlot.mitAuflistung,
          'Auflistung.docx',
        );
        final stand = bearbeitung.stand(
          zustandMit(
            ohne: ['Kennzeichen', 'Frist'],
            mit: ['Frist', 'Schadensaufstellung', 'Zeichen'],
          ),
        );

        bearbeitung.alleUebernehmen(stand.platzhalterOhneFeld);

        expect(bearbeitung.feldnamen, [
          'Kennzeichen',
          'Unfalldatum',
          'Frist',
          'Zeichen',
        ]);
      },
    );
  });

  test('Verschieben zählt wie ReorderableListView', () {
    final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
    bearbeitung.feldHinzufuegen(name: 'Frist');

    // Das erste Feld hinter das letzte ziehen: Der Zielindex zählt die Lücke
    // vor dem Herausnehmen, ist also 3 und nicht 2.
    bearbeitung.verschiebe(0, 3);
    expect(bearbeitung.feldnamen, ['Unfalldatum', 'Frist', 'Kennzeichen']);

    // Und wieder zurück nach vorn — dort zählt der Index unverändert.
    bearbeitung.verschiebe(2, 0);
    expect(bearbeitung.feldnamen, ['Kennzeichen', 'Unfalldatum', 'Frist']);
  });

  group('Word-Dateien', () {
    test('setzen und entfernen je Slot, unabhängig voneinander', () {
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);

      bearbeitung.setzePfad(TemplateFileSlot.mitAuflistung, 'Auflistung.docx');
      expect(bearbeitung.pfadOhneAuflistung, 'HGN.docx');
      expect(
        bearbeitung.pfad(TemplateFileSlot.mitAuflistung),
        'Auflistung.docx',
      );

      bearbeitung.setzePfad(TemplateFileSlot.ohneAuflistung, null);
      expect(bearbeitung.pfadOhneAuflistung, isNull);
      expect(bearbeitung.pfadMitAuflistung, 'Auflistung.docx');
    });
  });

  group('Stand', () {
    test(
      'rechnet über beide Dateien und zählt einen Platzhalter nur einmal',
      () {
        final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
        bearbeitung.setzePfad(
          TemplateFileSlot.mitAuflistung,
          'Auflistung.docx',
        );

        final stand = bearbeitung.stand(
          zustandMit(
            ohne: ['Kennzeichen', 'Frist'],
            mit: ['Kennzeichen', 'Frist', 'Schadensaufstellung'],
          ),
        );

        expect(stand.platzhalterOhneFeld, ['Frist']);
        // „Unfalldatum" kommt in keiner Datei vor — Warnung, kein Mangel.
        expect(stand.felderOhneVorkommen, ['Unfalldatum']);
        expect(stand.istVollstaendig, isFalse);
        expect(stand.hatDateiOhne, isTrue);
        expect(stand.hatDateiMit, isTrue);
      },
    );

    test('eine verknüpfte Datei ohne gelesene Platzhalter macht den Stand '
        'unbekannt', () {
      // Der Ladezustand ist kein Befund: Was noch niemand gelesen hat, darf
      // weder als „vollständig" noch als Warnung dastehen.
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);

      final stand = bearbeitung.stand(const TemplatePlaceholdersState());

      expect(stand.platzhalterUnbekannt, isTrue);
      expect(stand.felderOhneVorkommen, isEmpty);
    });

    test('der Stand folgt den Feldnamen aus dem Formular, nicht dem Label', () {
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      bearbeitung.formGroup.control('field_1').updateValue('Frist');

      final stand = bearbeitung.stand(
        zustandMit(ohne: ['Kennzeichen', 'Frist']),
      );

      expect(stand.platzhalterOhneFeld, isEmpty);
      expect(stand.istVollstaendig, isTrue);
    });
  });
}
