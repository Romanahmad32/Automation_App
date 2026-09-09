import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Der Zustand der Registeransicht (§6.2): Zeilen und Stand kommen zusammen,
/// der Filter überlebt ein Nachladen, und eine gescheiterte Berichtigung sagt
/// das, statt still zu tun, als wäre sie geschehen.
void main() {
  late FakeRegisterZeilen zeilenPort;
  late FakeRegisterHistorie historiePort;

  RegisterCubit cubit() => RegisterCubit(zeilenPort, historiePort);

  setUp(() {
    // In der Reihenfolge, in der das Backend liefert: Jahrgang aufsteigend.
    zeilenPort = FakeRegisterZeilen(zeilen: [historieZeile(), vorgangsZeile()]);
    historiePort = FakeRegisterHistorie(
      stand: const RegisterHistorieStand(
        jahrgaenge: [JahrgangStand(jahrgang: 2019, zeilen: 3)],
      ),
    );
  });

  test('lädt Zeilen und Stand in einem Zug', () async {
    final register = cubit();

    await register.lade();

    expect(register.state.zeilen, hasLength(2));
    expect(register.state.stand.kleinsterJahrgang, 2019);
    expect(register.state.laedt, isFalse);
    expect(register.state.fehler, isNull);
  });

  /// Ein Dienst, der nicht antwortet, darf keine leere Tabelle vortäuschen —
  /// „keine Zeilen" und „nicht erreichbar" sind zwei verschiedene Antworten.
  test('meldet einen Fehlschlag, statt eine leere Ansicht zu zeigen', () async {
    zeilenPort.fehler = Exception('Zeitüberschreitung');
    final register = cubit();

    await register.lade();

    expect(register.state.fehler, contains('nicht erreichbar'));
    expect(register.state.laedt, isFalse);
  });

  test('der Filter liegt im Cubit und überlebt ein Nachladen', () async {
    final register = cubit();
    await register.lade();

    register.filtern(const RegisterFilter.imJahr(2019));
    await register.lade();

    expect(register.state.filter.vonJahr, 2019);
    expect(register.state.sichtbar.single.jahr, '2019');
  });

  /// Angesehen werden fast immer die jüngsten Zeilen — nach tausenden
  /// übernommenen stünden sie sonst ganz unten.
  test('zeigt die neuesten Zeilen zuerst und lässt sich umdrehen', () async {
    final register = cubit();

    await register.lade();
    expect(register.state.sichtbar.map((z) => z.jahr), ['2026', '2019']);

    register.sortieren(RegisterReihenfolge.aeltesteZuerst);
    expect(register.state.sichtbar.map((z) => z.jahr), ['2019', '2026']);
  });

  group('aendereHistorie', () {
    test('schreibt und lädt danach neu', () async {
      final register = cubit();
      await register.lade();
      final vorher = zeilenPort.abrufe;

      final erfolg = await register.aendereHistorie(
        7,
        const RegisterHistorieAenderung(mandant: 'Bernd Mustermann'),
      );

      expect(erfolg, isTrue);
      expect(historiePort.geaendert.single.id, 7);
      expect(
        historiePort.geaendert.single.aenderung.mandant,
        'Bernd Mustermann',
      );
      // Eine Berichtigung rechnet die Befunde neu und verschiebt damit auch
      // die Zahlen im Stand — deshalb wird alles neu geholt.
      expect(zeilenPort.abrufe, vorher + 1);
    });

    test('meldet einen Fehlschlag und lädt dann nicht neu', () async {
      historiePort.fehler = Exception('404');
      final register = cubit();
      await register.lade();
      final vorher = zeilenPort.abrufe;

      final erfolg = await register.aendereHistorie(
        7,
        const RegisterHistorieAenderung(),
      );

      expect(erfolg, isFalse);
      expect(zeilenPort.abrufe, vorher);
    });
  });

  group('loescheHistorie', () {
    /// §6.3: Eine historische Zeile geht für sich — sie hat keinen Vorgang,
    /// der mitginge.
    test('löscht und lädt danach neu', () async {
      final register = cubit();
      await register.lade();
      final vorher = zeilenPort.abrufe;

      final erfolg = await register.loescheHistorie(7);

      expect(erfolg, isTrue);
      expect(historiePort.geloescht, [7]);
      // Eine Löschung verschiebt die Zahlen im Stand ihres Jahrgangs — auch
      // hier wird deshalb alles neu geholt.
      expect(zeilenPort.abrufe, vorher + 1);
    });

    test('meldet einen Fehlschlag und lädt dann nicht neu', () async {
      historiePort.fehler = Exception('404');
      final register = cubit();
      await register.lade();
      final vorher = zeilenPort.abrufe;

      final erfolg = await register.loescheHistorie(7);

      expect(erfolg, isFalse);
      expect(zeilenPort.abrufe, vorher);
    });
  });
}
