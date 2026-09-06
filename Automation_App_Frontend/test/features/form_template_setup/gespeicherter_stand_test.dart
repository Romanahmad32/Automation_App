import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der **gespeicherte** Stand einer Vorlage (#104 Stufe 4): Die Übersicht kann
/// nicht rechnen, was der Editor rechnet — sie kennt die Platzhalter der
/// Word-Dateien nicht, und sie für dreißig Vorlagen einzulesen hieße, beim
/// Öffnen des Tabs dreißig Word-Dokumente zu öffnen. Der Editor schreibt sein
/// Ergebnis deshalb beim Speichern mit, in dieselbe opake `fields`-Spalte, die
/// das Backend unverändert durchreicht.
///
/// Geprüft wird hier beides: die Form auf der Leitung (damit ein alter
/// Datensatz weiter gelesen wird) und die Aussage „unbekannt", die ein
/// Datensatz ohne Eintrag bekommt — sie ist **nicht** dasselbe wie
/// „unvollständig".
void main() {
  const feld = FieldData(
    order: 0,
    label: 'Kennzeichen',
    required: true,
    inputType: InputType.text,
  );

  /// Die Feldliste, wie sie bisher (und weiter) auf der Leitung steht.
  final felderJson = [feld.toJson()];

  group('aus einer Rechnung', () {
    test('übernimmt genau VorlagenStand — keine zweite Rechnung', () {
      final stand = VorlagenStand.bestimme(
        hatDateiOhne: true,
        hatDateiMit: false,
        platzhalterOhne: const ['Kennzeichen', 'Unfalldatum'],
        platzhalterMit: null,
        feldnamen: const ['Kennzeichen', 'Mandant'],
      );

      final gespeichert = GespeicherterStand.aus(stand);

      expect(gespeichert.vollstaendig, stand.istVollstaendig);
      expect(gespeichert.offen, stand.anzahlOffen);
      expect(gespeichert.warnungen, stand.hatWarnungen);
      // Zur Sicherheit auch die Werte selbst: ein Platzhalter ohne Feld
      // (Unfalldatum) und ein Feld ohne Vorkommen (Mandant).
      expect(gespeichert.vollstaendig, isFalse);
      expect(gespeichert.offen, 2);
      expect(gespeichert.warnungen, isTrue);
    });

    test('eine Vorlage ohne jede Datei ist unvollständig, aber ohne Zahl', () {
      // Der Stand einer frischen Kopie: Ohne Word-Datei kennt niemand die
      // Platzhalter, also ist nichts zu zählen — unvollständig ist sie
      // trotzdem.
      expect(GespeicherterStand.ohneDatei.vollstaendig, isFalse);
      expect(GespeicherterStand.ohneDatei.offen, 0);
      expect(GespeicherterStand.ohneDatei.warnungen, isFalse);
    });
  });

  group('Form auf der Leitung', () {
    test('verpackt Felder und Stand in ein Objekt', () {
      const stand = GespeicherterStand(
        vollstaendig: false,
        offen: 2,
        warnungen: true,
      );

      final verpackt = GespeicherterStand.verpacke(felderJson, stand);

      expect(verpackt, isA<Map<String, dynamic>>());
      final karte = verpackt as Map<String, dynamic>;
      expect(karte['felder'], felderJson);
      expect(karte['stand'], {
        'version': 1,
        'vollstaendig': false,
        'offen': 2,
        'warnungen': true,
      });
    });

    test('ohne Stand bleibt die nackte Liste stehen', () {
      // Wer den Stand nicht kennt, soll nicht so tun als ob: Dann geht genau
      // das hinaus, was vor #104 hinausging.
      expect(GespeicherterStand.verpacke(felderJson, null), felderJson);
    });

    test('liest die Felder aus beiden Formen', () {
      expect(GespeicherterStand.felderAus(felderJson), felderJson);
      expect(
        GespeicherterStand.felderAus({'felder': felderJson, 'stand': null}),
        felderJson,
      );
    });

    test('unbekannte oder kaputte Formen ergeben keine Felder', () {
      expect(GespeicherterStand.felderAus(null), isEmpty);
      expect(GespeicherterStand.felderAus('Unfug'), isEmpty);
      expect(GespeicherterStand.felderAus(const {'felder': 42}), isEmpty);
    });
  });

  group('lesen', () {
    test('alter Datensatz ohne Eintrag → unbekannt', () {
      // Die nackte Liste ist der Bestand: Vorlagen, die vor #104 gespeichert
      // wurden, haben keinen Stand — und sind deshalb nicht „unvollständig",
      // sondern „noch nicht geprüft".
      expect(GespeicherterStand.lesen(felderJson), isNull);
    });

    test('neue Form ohne Stand-Schlüssel → unbekannt', () {
      expect(GespeicherterStand.lesen({'felder': felderJson}), isNull);
    });

    test('liest den Stand der eigenen Fassung', () {
      final gelesen = GespeicherterStand.lesen({
        'felder': felderJson,
        'stand': {
          'version': 1,
          'vollstaendig': true,
          'offen': 0,
          'warnungen': false,
        },
      });

      expect(gelesen, isNotNull);
      expect(gelesen!.vollstaendig, isTrue);
      expect(gelesen.offen, 0);
      expect(gelesen.warnungen, isFalse);
    });

    test('fremde Fassung → unbekannt statt falsch geraten', () {
      // Eine Fassung, deren Bedeutung wir nicht kennen, wird nicht ausgelegt.
      // „Noch nicht geprüft" ist die einzige Aussage, die dann sicher stimmt.
      expect(
        GespeicherterStand.lesen({
          'felder': felderJson,
          'stand': {'version': 99, 'vollstaendig': true},
        }),
        isNull,
      );
      expect(
        GespeicherterStand.lesen({
          'felder': felderJson,
          'stand': {'vollstaendig': true},
        }),
        isNull,
      );
      expect(
        GespeicherterStand.lesen({'felder': felderJson, 'stand': 'ja'}),
        isNull,
      );
    });
  });

  group('FormTemplate', () {
    test('liest eine Bestandsvorlage (nackte Liste) weiter', () {
      final vorlage = FormTemplate.fromJson({
        'id': 7,
        'templateName': 'Anspruchsschreiben',
        'fields': felderJson,
        'wordFilePathOhneAuflistung': 'ohne.docx',
        'wordFilePathMitAuflistung': null,
      });

      expect(vorlage.fields.single.label, 'Kennzeichen');
      expect(vorlage.stand, isNull);
    });

    test('schreibt und liest den Stand über die opake Spalte', () {
      const vorlage = FormTemplate(
        id: 7,
        templateName: 'Anspruchsschreiben',
        fields: [feld],
        wordFilePathOhneAuflistung: 'ohne.docx',
        stand: GespeicherterStand(
          vollstaendig: false,
          offen: 3,
          warnungen: true,
        ),
      );

      final zurueck = FormTemplate.fromJson(vorlage.toJson());

      expect(zurueck.fields.single.label, 'Kennzeichen');
      expect(zurueck.stand, vorlage.stand);
    });

    test('ohne Stand bleibt das JSON byteidentisch zu früher', () {
      const vorlage = FormTemplate(
        id: 7,
        templateName: 'Anspruchsschreiben',
        fields: [feld],
      );

      expect(vorlage.toJson()['fields'], felderJson);
    });

    test('copyWith gibt den Stand auf, sobald sich seine Grundlage ändert', () {
      const vorlage = FormTemplate(
        id: 7,
        templateName: 'Anspruchsschreiben',
        fields: [feld],
        stand: GespeicherterStand(
          vollstaendig: true,
          offen: 0,
          warnungen: false,
        ),
      );

      // Nur der Name: Der Stand hängt nicht daran und bleibt.
      expect(vorlage.copyWith(templateName: 'Neu').stand, vorlage.stand);
      // Felder oder Dateien: Wer sie ändert, ohne neu zu rechnen, hat keine
      // Zusage mehr zu machen — „noch nicht geprüft" statt einer alten.
      expect(vorlage.copyWith(fields: const []).stand, isNull);
      expect(
        vorlage.copyWith(wordFilePathMitAuflistung: () => 'mit.docx').stand,
        isNull,
      );
    });
  });
}
