import 'dart:async';

import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/einlese_reaktion.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was auf ein fertig gelesenes Word-Dokument folgt (#104 Stufe 3c) — ohne
/// Detailseite geprüft, genau dafür ist [EinleseReaktion] aus ihr
/// herausgezogen. Vom Widgetbaum bleibt ein `BuildContext` übrig, den die
/// Rückmeldung braucht; die Rückfrage nach einem Dateiwechsel kommt als
/// Funktion herein und braucht keinen echten Dialog.
///
/// Die beiden Zusagen, an denen alles hängt: **Angelegt wird nur bei einer
/// neuen Vorlage und je Slot nur einmal** — sonst käme ein gelöschtes Feld beim
/// nächsten Einlesen von selbst zurück. Und **gefragt wird nur, wenn eine
/// Datei wirklich neu gelesen wurde**: Der Vorschlag ist das Löschen von
/// Feldern, ein Ladezustand darf ihn nicht auslösen.
void main() {
  const pfad = 'C:/Vorlagen/HGn.docx';

  const vorlage = FormTemplate(
    id: 3,
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
        label: 'Frist',
        required: false,
        inputType: InputType.text,
      ),
    ],
    wordFilePathOhneAuflistung: pfad,
  );

  const pfadMit = 'C:/Vorlagen/SA.docx';

  /// Eine Vorlage mit **beiden** Word-Dateien. Nur damit lässt sich prüfen,
  /// was passiert, während über der einen Datei schon eine Frage steht.
  const vorlageZweiDateien = FormTemplate(
    id: 4,
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
        label: 'Frist',
        required: false,
        inputType: InputType.text,
      ),
      FieldData(
        order: 2,
        label: 'Summe',
        required: false,
        inputType: InputType.text,
      ),
    ],
    wordFilePathOhneAuflistung: pfad,
    wordFilePathMitAuflistung: pfadMit,
  );

  const slot = TemplateFileSlot.ohneAuflistung;

  TemplatePlaceholdersState beide(
    SlotPlaceholders ohne,
    SlotPlaceholders mit,
  ) => const TemplatePlaceholdersState()
      .withSlot(TemplateFileSlot.ohneAuflistung, ohne)
      .withSlot(TemplateFileSlot.mitAuflistung, mit);

  TemplatePlaceholdersState geladen(List<String> platzhalter) =>
      const TemplatePlaceholdersState().withSlot(
        slot,
        SlotPlaceholdersLoaded(platzhalter),
      );

  TemplatePlaceholdersState laedt() => const TemplatePlaceholdersState()
      .withSlot(slot, const SlotPlaceholdersLoading());

  TemplatePlaceholdersState fehlgeschlagen() =>
      const TemplatePlaceholdersState().withSlot(
        slot,
        const SlotPlaceholdersError('Die Datei ist in Word geöffnet.'),
      );

  /// Der Kontext einer gewöhnlichen Seite — so wie die Detailseite ihn hat.
  late BuildContext kontext;

  Future<void> baueSeite(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            kontext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  /// Mitschrift der Rückfrage: womit sie gerufen wurde und was sie antwortet.
  late String? gefragtNach;
  late List<String>? gefragteFelder;
  late int aufbauten;

  setUp(() {
    gefragtNach = null;
    gefragteFelder = null;
    aufbauten = 0;
  });

  /// [antwort] `null` heißt „alles behalten" — die Rückfrage wird gestellt,
  /// aber nichts entfernt.
  EinleseReaktion reaktion({List<String>? antwort, bool gesperrt = false}) =>
      EinleseReaktion(
        onGeaendert: () => aufbauten++,
        gesperrt: () => gesperrt,
        dialog: (context, {required dateiname, required felder}) async {
          gefragtNach = dateiname;
          gefragteFelder = felder;
          return antwort ?? const [];
        },
      );

  group('Felder anlegen', () {
    testWidgets('eine neue Vorlage bekommt ihre Felder von selbst', (
      tester,
    ) async {
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(null)..setzePfad(slot, pfad);
      final reagiert = reaktion();

      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );

      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
      expect(aufbauten, 1);

      // Die Meldung nennt beide Zahlen: erkannt und angelegt.
      await tester.pump();
      expect(
        find.textContaining('2 Platzhalter erkannt, 2 Felder angelegt'),
        findsOneWidget,
      );
    });

    testWidgets('derselbe Slot legt beim zweiten Zustand nichts erneut an', (
      tester,
    ) async {
      // Sonst käme ein Feld, das der Anwalt inzwischen gelöscht hat, beim
      // nächsten Zustand von selbst zurück.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(null)..setzePfad(slot, pfad);
      final reagiert = reaktion();

      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(kontext, bearbeitung, geladen(['Kennzeichen']));
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );

      expect(bearbeitung.feldnamen, ['Kennzeichen']);

      // Die Meldung der ersten Übernahme steht noch aus: Ohne ein Bild dazu
      // wird ihr Stapel nie gebaut, und sein Timer läuft über das Testende
      // hinaus weiter.
      await tester.pump();
    });

    testWidgets('einer bestehenden Vorlage wird nichts angelegt', (
      tester,
    ) async {
      // Dort stünde die Übernahme gegen Handarbeit, die schon da ist.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion();

      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist', 'Zeichen']),
      );

      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
      expect(aufbauten, 0);
    });
  });

  group('Abgleich nach Dateiwechsel', () {
    testWidgets('ein weggefallener Platzhalter wird zur Rückfrage', (
      tester,
    ) async {
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion(antwort: const ['Frist']);

      // Erstlauf beim Öffnen: Das ist das „vorher", noch keine Frage.
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      expect(gefragtNach, isNull);

      // Dateiwechsel: erst Laden, dann die neue, kürzere Liste.
      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(kontext, bearbeitung, geladen(['Kennzeichen']));

      // Der Dateiname kommt aus dem Pfad des gerade gelesenen Slots.
      expect(gefragtNach, 'HGn.docx');
      expect(gefragteFelder, ['Frist']);
      expect(bearbeitung.feldnamen, ['Kennzeichen']);
      expect(aufbauten, 1);
    });

    testWidgets('beide Dateien nacheinander gewählt fragen nichts', (
      tester,
    ) async {
      // Der Regelweg auf der Auswahlseite (#104 Stufe 5): Der Anwalt
      // verknüpft erst die eine, dann die andere Datei. Die Felder der ersten
      // kommen **in ihr** weiter vor — nichts ist verloren, also darf keine
      // Rückfrage aufgehen. Ohne diese Zusage stünde mitten in der Auswahl ein
      // Dialog, der das Löschen gerade angelegter Felder vorschlägt.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(null)
        ..setzePfad(TemplateFileSlot.ohneAuflistung, pfad);
      final reagiert = reaktion(antwort: const ['Kennzeichen', 'Frist']);

      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);

      // Die zweite Datei kommt dazu, die erste bleibt verknüpft.
      bearbeitung.setzePfad(TemplateFileSlot.mitAuflistung, pfadMit);
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        beide(
          const SlotPlaceholdersLoaded(['Kennzeichen', 'Frist']),
          const SlotPlaceholdersLoading(),
        ),
      );
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        beide(
          const SlotPlaceholdersLoaded(['Kennzeichen', 'Frist']),
          const SlotPlaceholdersLoaded(['Summe', 'Restwert']),
        ),
      );

      expect(gefragtNach, isNull);
      expect(gefragteFelder, isNull);
      // Und die Felder beider Dateien stehen da.
      expect(bearbeitung.feldnamen, [
        'Kennzeichen',
        'Frist',
        'Summe',
        'Restwert',
      ]);

      // Die Meldungen der beiden Übernahmen stehen noch aus: Ohne ein Bild
      // dazu wird ihr Stapel nie gebaut, und seine Timer laufen über das
      // Testende hinaus weiter.
      await tester.pump();
    });

    testWidgets('„Behalten" lässt jedes Feld stehen', (tester) async {
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion();

      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(kontext, bearbeitung, geladen(['Kennzeichen']));

      expect(gefragteFelder, ['Frist']);
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
      expect(aufbauten, 0);
    });

    testWidgets('bei unbekannter Platzhalterliste wird nicht gefragt', (
      tester,
    ) async {
      // Ein Lesefehler (Datei in Word geöffnet) ist kein Befund — er dürfte
      // sonst das Löschen jedes Feldes vorschlagen.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion(antwort: const ['Frist']);

      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(kontext, bearbeitung, fehlgeschlagen());

      expect(gefragtNach, isNull);
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
    });

    testWidgets('ohne frisch gelesenen Slot gibt es keine Rückfrage', (
      tester,
    ) async {
      // Der Zustand ändert sich, ohne dass eine Datei neu gelesen wurde —
      // hier durch das Entfernen der Verknüpfung. Was dann ins Leere läuft,
      // steht als Warnung an der Feldzeile, nicht als Löschvorschlag.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion(antwort: const ['Frist']);

      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      await reagiert.verarbeite(kontext, bearbeitung, geladen(['Kennzeichen']));

      expect(gefragtNach, isNull);
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
    });

    testWidgets('eine offene Rückfrage verschluckt den zweiten Slot nicht', (
      tester,
    ) async {
      // Die Rennbedingung: Über Datei A steht die Frage noch offen, da wird
      // Datei B fertig neu eingelesen. Würde der zuletzt gesehene Stand jetzt
      // trotzdem fortgeschrieben, wäre der Verlust in B nie wieder zu sehen —
      // die nächste Rechnung vergliche gegen einen Stand, in dem er schon
      // eingetreten ist.
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlageZweiDateien);

      final ersteAntwort = Completer<List<String>>();
      final fragen = <String>[];
      final gefragt = <List<String>>[];
      final reagiert = EinleseReaktion(
        onGeaendert: () => aufbauten++,
        dialog: (context, {required dateiname, required felder}) {
          fragen.add(dateiname);
          gefragt.add(felder);
          // Die erste Frage bleibt stehen — genau die Lage, in der der zweite
          // Slot fertig wird.
          return fragen.length == 1
              ? ersteAntwort.future
              : Future.value(felder);
        },
      );

      final grundstand = beide(
        const SlotPlaceholdersLoaded(['Kennzeichen', 'Frist']),
        const SlotPlaceholdersLoaded(['Summe']),
      );
      final bNeu = beide(
        const SlotPlaceholdersLoaded(['Kennzeichen']),
        const SlotPlaceholdersLoaded(['Andere']),
      );

      await reagiert.verarbeite(kontext, bearbeitung, grundstand);
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        beide(
          const SlotPlaceholdersLoading(),
          const SlotPlaceholdersLoaded(['Summe']),
        ),
      );
      final ersteFrage = reagiert.verarbeite(
        kontext,
        bearbeitung,
        beide(
          const SlotPlaceholdersLoaded(['Kennzeichen']),
          const SlotPlaceholdersLoaded(['Summe']),
        ),
      );
      await tester.pump();
      expect(fragen, ['HGn.docx']);

      // Währenddessen wird die zweite Datei getauscht.
      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        beide(
          const SlotPlaceholdersLoaded(['Kennzeichen']),
          const SlotPlaceholdersLoading(),
        ),
      );
      await reagiert.verarbeite(kontext, bearbeitung, bNeu);
      expect(fragen, [
        'HGn.docx',
      ], reason: 'über einer offenen Frage geht keine zweite auf');

      ersteAntwort.complete(const ['Frist']);
      await ersteFrage;

      // Der nächste Zustand holt den übersprungenen Befund nach.
      await reagiert.verarbeite(kontext, bearbeitung, bNeu);

      expect(fragen, ['HGn.docx', 'SA.docx']);
      expect(gefragt.last, ['Summe']);
      expect(bearbeitung.feldnamen, ['Kennzeichen']);
    });

    testWidgets('solange gespeichert wird, geht keine Rückfrage auf', (
      tester,
    ) async {
      // Gesperrt ist auch die Verlassen-Wache: Ein offener Dialog finge den
      // Erfolgs-`pop` der Seite ab, und die Seite meldete „nichts geändert".
      await baueSeite(tester);
      final bearbeitung = VorlagenBearbeitung.fuer(vorlage);
      final reagiert = reaktion(antwort: const ['Frist'], gesperrt: true);

      await reagiert.verarbeite(
        kontext,
        bearbeitung,
        geladen(['Kennzeichen', 'Frist']),
      );
      await reagiert.verarbeite(kontext, bearbeitung, laedt());
      await reagiert.verarbeite(kontext, bearbeitung, geladen(['Kennzeichen']));

      expect(gefragtNach, isNull);
      expect(bearbeitung.feldnamen, ['Kennzeichen', 'Frist']);
    });
  });
}
