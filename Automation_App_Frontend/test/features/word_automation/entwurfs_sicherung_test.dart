import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/entwurfs_sicherung.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vorgang_starten/vorgang_starten_doubles.dart';

/// Mangel 1 aus #133: Jede Meldung des `FormWertBeobachter` rief bisher
/// ungeprüft [EntwurfsSicherung.jetzt] — auch das bloße Nachmelden beim
/// Verlassen ohne neue Eingabe. Das kostete einen PUT am Dienst pro Meldung,
/// nicht pro Änderung. Diese Datei prüft die Ablage direkt, ohne Cubit oder
/// Formular — nur mit der Frage, wann tatsächlich geschrieben wird.
void main() {
  const referenz = '84/26 C03_GG-XY 123';
  const andereReferenz = '85/26 C03_GG-AB 456';

  late VorgangAblageDouble ablage;
  late VorgangCubit vorgaenge;
  late VorgangPersistenzFehlerCubit fehler;
  late EntwurfsSicherung sicherung;

  Vorgang vorgang(String schluessel) => Vorgang.ausAnfrage(
    referenz: schluessel,
    angefragtAm: DateTime(2026, 6, 1),
  );

  setUp(() async {
    ablage = VorgangAblageDouble();
    fehler = VorgangPersistenzFehlerCubit();
    vorgaenge = VorgangCubit(ablage, fehler);
    sicherung = EntwurfsSicherung(vorgaenge);
    await vorgaenge.aktualisiere(vorgang(referenz));
  });

  tearDown(() async {
    await vorgaenge.close();
    await fehler.close();
  });

  test('zwei gleiche Meldungen schreiben nur einmal', () {
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );

    expect(ablage.entwuerfe, hasLength(1));
  });

  test('eine geänderte Meldung schreibt erneut', () {
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'Allianz'},
      aufstellung: null,
    );

    expect(ablage.entwuerfe, hasLength(2));
    expect(ablage.entwuerfe.last?.feldWerte, {'Versicherer': 'Allianz'});
  });

  /// Ein Vorgangswechsel setzt die Merkung zurück: Derselbe Inhalt am
  /// **anderen** Vorgang darf sich nicht am gemerkten Stand des vorigen
  /// vorbeischummeln.
  test('ein Vorgangswechsel setzt die Merkung zurück', () async {
    await vorgaenge.aktualisiere(vorgang(andereReferenz));

    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );
    sicherung.jetzt(
      referenz: andereReferenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );

    expect(ablage.entwuerfe, hasLength(2));
  });

  /// Der Zeitstempel darf den Vergleich nicht verfälschen: Zwei inhaltlich
  /// gleiche Meldungen liegen unweigerlich zu verschiedenen Zeitpunkten.
  test('der Zeitstempel selbst ist keine Änderung', () async {
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    sicherung.jetzt(
      referenz: referenz,
      werte: const {'Versicherer': 'HUK'},
      aufstellung: null,
    );

    expect(ablage.entwuerfe, hasLength(1));
  });

  /// Befund 2 der Review-Nachbesserung zu #133: Vor dem ersten eigenen
  /// Schreiben ist eine Meldung ohne Abweichung kein Löschauftrag — der
  /// Vorgang trägt (aus dem `setUp`) ohnehin keinen Entwurf, also gibt es
  /// nichts zu löschen. Ein nie angerührtes Formular verlassen darf keine
  /// DELETE-Anfrage ins Leere auslösen.
  test('nie angerührt und ohne Entwurf am Vorgang schreibt nichts', () {
    sicherung.jetzt(referenz: referenz, werte: const {}, aufstellung: null);

    expect(ablage.entwuerfe, isEmpty);
  });

  /// Die Gegenprobe: Trägt der Vorgang schon einen Entwurf, ist dieselbe
  /// Meldung sehr wohl ein Löschauftrag — sie sagt „das Formular zeigt jetzt
  /// die Vorbelegung", und der veraltete Entwurf muss weg.
  test(
    'ohne Abweichung, aber mit Entwurf am Vorgang löscht genau einmal',
    () async {
      await vorgaenge.aktualisiere(
        vorgang(referenz).copyWith(
          entwurf: () => VorgangEntwurf(
            gespeichertAm: DateTime(2026, 6, 2),
            feldWerte: const {'Versicherer': 'HUK'},
          ),
        ),
      );

      sicherung.jetzt(referenz: referenz, werte: const {}, aufstellung: null);

      expect(ablage.entwuerfe, hasLength(1));
      expect(ablage.entwuerfe.single, isNull);
    },
  );
}
