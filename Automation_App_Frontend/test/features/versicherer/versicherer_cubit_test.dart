import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-Memory-Ersatz der Wissensbasis. [schlaegtFehl] bildet den Backend-Ausfall
/// nach — der Fall, auf dem die halbe Datei beruht.
class _FakeVersichererRepository implements VersichererRepository {
  List<Versicherer> eintraege;
  bool schlaegtFehl;
  int ladeAufrufe = 0;

  _FakeVersichererRepository({
    this.eintraege = const [],
    this.schlaegtFehl = false,
  });

  @override
  Future<List<Versicherer>> ladeVersicherer() async {
    ladeAufrufe++;
    if (schlaegtFehl) throw Exception('Backend nicht erreichbar');
    return eintraege;
  }
}

Versicherer versicherer(int id, String name) => Versicherer(id: id, name: name);

void main() {
  // Der Konstruktor lädt selbst, also asynchron: ohne diesen Durchlauf steht
  // der Cubit im Test noch auf seinem Anfangszustand.
  Future<void> ladenAbwarten() => Future<void>.delayed(Duration.zero);

  group('Laden', () {
    test('lädt sich beim Erzeugen selbst', () async {
      final repository = _FakeVersichererRepository(
        eintraege: [versicherer(1, 'HUK-COBURG')],
      );

      final cubit = VersichererCubit(repository);
      await ladenAbwarten();

      expect(repository.ladeAufrufe, 1);
      expect(cubit.state, [versicherer(1, 'HUK-COBURG')]);
    });

    test('ein Ladefehler bleibt still und lässt die Liste leer', () async {
      // Bewusstes Verhalten, nicht vergessene Fehlerbehandlung: die
      // Wissensbasis ist Komfort. Wer hier eine Fehlermeldung einbaut, meldet
      // dem Anwalt einen Ausfall, der seinen Ablauf gar nicht aufhält.
      final repository = _FakeVersichererRepository(schlaegtFehl: true);

      final cubit = VersichererCubit(repository);
      await ladenAbwarten();

      expect(cubit.state, isEmpty);
    });

    test('ladeErneut holt den inzwischen gelernten Eintrag nach', () async {
      // Der Grund für die Doppelberechnung in vorgangsdaten_form.dart: Das
      // Backend lernt erst beim Parsen der Antwort dazu.
      final repository = _FakeVersichererRepository();
      final cubit = VersichererCubit(repository);
      await ladenAbwarten();
      expect(cubit.state, isEmpty);

      repository.eintraege = [versicherer(7, 'Allianz')];
      await cubit.ladeErneut();

      expect(cubit.state, [versicherer(7, 'Allianz')]);
    });

    test('ein späterer Ladefehler wirft den Bestand nicht weg', () async {
      final repository = _FakeVersichererRepository(
        eintraege: [versicherer(1, 'HUK-COBURG')],
      );
      final cubit = VersichererCubit(repository);
      await ladenAbwarten();

      repository.schlaegtFehl = true;
      await cubit.ladeErneut();

      expect(cubit.state, [versicherer(1, 'HUK-COBURG')]);
    });
  });

  group('findeZuName', () {
    late VersichererCubit cubit;

    setUp(() async {
      cubit = VersichererCubit(
        _FakeVersichererRepository(
          eintraege: [
            versicherer(1, 'HUK-COBURG'),
            versicherer(2, 'Allianz'),
            versicherer(3, 'Deutsche Allgemeine Versicherung'),
          ],
        ),
      );
      await ladenAbwarten();
    });

    test('findet den Eintrag unabhängig von Schreibweise und Leerraum', () {
      // Die Namen kommen aus einer geparsten Antwortmail, nicht aus einer
      // Auswahlliste: Groß-/Kleinschreibung und Leerraum sind dort beliebig.
      expect(cubit.findeZuName('HUK-COBURG')?.id, 1);
      expect(cubit.findeZuName('huk-coburg')?.id, 1);
      expect(cubit.findeZuName('  Allianz  ')?.id, 2);
      // Zeilenumbrüche und doppelte Leerzeichen entstehen beim Herauslösen des
      // Namens aus der Mail; der Vergleich zieht sie auf beiden Seiten zusammen.
      expect(cubit.findeZuName('Deutsche  Allgemeine\nVersicherung')?.id, 3);
    });

    test('unbekannte, leere und fehlende Namen liefern nichts', () {
      expect(cubit.findeZuName('Gothaer'), isNull);
      expect(cubit.findeZuName(''), isNull);
      expect(cubit.findeZuName('   '), isNull);
      expect(cubit.findeZuName(null), isNull);
    });
  });
}
