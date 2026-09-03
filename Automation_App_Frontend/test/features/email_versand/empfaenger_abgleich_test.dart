import 'package:automation_app/features/email_versand/domain/services/empfaenger_abgleich.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Empfängerabgleich beim Wechsel des Vorgangs (§4.7).
///
/// Der Fall, der diese Datei trägt: Im Postfach trägt der Anwalt zuerst eine
/// Adresse von Hand ein und ordnet den Vorgang danach zu. Sie darf dabei nicht
/// verschwinden — eine überflüssige Adresse sieht er, eine verschwundene nicht.
void main() {
  test('Vorschläge des alten Vorgangs gehen, getippte bleiben', () {
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const ['alt.mandant@example.de', 'sachbearbeiter@example.de'],
      zuvorVorbelegt: const ['alt.mandant@example.de'],
      neueVorschlaege: const ['neu.mandant@example.de', 'schaden@huk.de'],
    );

    expect(abgeglichen.empfaenger, [
      'neu.mandant@example.de',
      'schaden@huk.de',
      'sachbearbeiter@example.de',
    ]);
  });

  test('die neuen Vorschläge stehen voran, wie beim ersten Aufgehen', () {
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const ['getippt@example.de'],
      zuvorVorbelegt: const [],
      neueVorschlaege: const ['mandant@example.de'],
    );

    expect(abgeglichen.empfaenger.first, 'mandant@example.de');
  });

  test('eine Adresse steht nur einmal, auch in anderer Schreibweise', () {
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const [' Mandant@Example.DE '],
      zuvorVorbelegt: const [],
      neueVorschlaege: const ['mandant@example.de'],
    );

    expect(abgeglichen.empfaenger, ['mandant@example.de']);
  });

  test('leere Einträge fallen weg', () {
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const ['', '  '],
      zuvorVorbelegt: const [],
      neueVorschlaege: const [''],
    );

    expect(abgeglichen.empfaenger, isEmpty);
  });

  test('eine getippte Adresse bleibt seine, auch als neuer Vorschlag', () {
    // Der Fall aus dem Postfach in seiner ganzen Laenge: Der Anwalt tippt die
    // Mandantenadresse, ordnet den Vorgang danach zu — dessen Vorschlaege
    // enthalten dieselbe Adresse —, und wechselt spaeter weiter. Zaehlte sie
    // ab der Zuordnung als Vorbelegung, verschwaende sie beim naechsten
    // Wechsel doch noch: derselbe wortlose Verlust, nur einen Schritt spaeter.
    final zuordnung = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const ['mandant@example.de'],
      zuvorVorbelegt: const [],
      neueVorschlaege: const ['mandant@example.de', 'schaden@huk.de'],
    );

    expect(zuordnung.vorbelegt, ['schaden@huk.de']);

    final weiter = EmpfaengerAbgleich.nachWechsel(
      vorhanden: zuordnung.empfaenger,
      zuvorVorbelegt: zuordnung.vorbelegt,
      neueVorschlaege: const ['zweiter@example.de'],
    );

    expect(weiter.empfaenger, ['zweiter@example.de', 'mandant@example.de']);
  });

  test('ohne neuen Vorgang bleibt nur, was der Anwalt eingetragen hat', () {
    // „Kein Vorgang" ist ein gleichberechtigter Eintrag (§4.7): Dann gibt es
    // keine Vorschlaege, und die Vorbelegung des alten Vorgangs muss gehen.
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const ['mandant@example.de', 'getippt@example.de'],
      zuvorVorbelegt: const ['mandant@example.de'],
      neueVorschlaege: const [],
    );

    expect(abgeglichen.empfaenger, ['getippt@example.de']);
  });

  test('die Vorbelegung ist genauso entdoppelt wie die Empfängerliste', () {
    // Beide Rückgaben derselben Funktion müssen dasselbe darüber sagen, was
    // „die vorbelegten Adressen" sind (ergänzt am 03.09.2026). `empfaenger`
    // war entdoppelt, `vorbelegt` nicht — zwei Vorschläge, die sich nur in
    // der Schreibweise unterscheiden, standen dort zweimal.
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: const [],
      zuvorVorbelegt: const [],
      neueVorschlaege: const ['Schaden@HUK.de', ' schaden@huk.de ', ''],
    );

    expect(abgeglichen.empfaenger, ['Schaden@HUK.de']);
    expect(abgeglichen.vorbelegt, ['Schaden@HUK.de']);
  });
}
