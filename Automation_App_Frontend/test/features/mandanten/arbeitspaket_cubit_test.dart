import 'dart:convert';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/kein_offener_ordner.dart';
import 'package:automation_app/features/mandanten/domain/usecases/hole_arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/usecases/schreibe_arbeitspaket_datei.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/arbeitspaket_cubit/arbeitspaket_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Die Historie im Speicher — geteilt von Abruf und Ausgabe, wie die eine
/// Tabelle im Backend. Nur so lässt sich prüfen, dass die Stand-Anzeige nach
/// dem Holen wirklich stimmt und nicht bloß der alte Stand stehen bleibt.
class PaketBuch {
  final List<Arbeitspaket> pakete = [];
  int abrufe = 0;

  Arbeitspaket trageEin(List<String> ordnernamen, int anzahl) {
    final genommen = ordnernamen.take(anzahl).toList();
    final paket = Arbeitspaket(
      nummer: pakete.length + 1,
      geholtAm: DateTime(2026, 9, 5, 10, 12),
      ordnerAnzahl: genommen.length,
      ordnernamen: genommen,
    );
    // Neuestes zuerst — so liefert es der Dienst.
    pakete.insert(0, paket);
    return paket;
  }
}

class FesteArbeitspakete implements UseCase<List<Arbeitspaket>, NoParams> {
  final PaketBuch buch;

  FesteArbeitspakete(this.buch);

  @override
  Future<Either<Failure, List<Arbeitspaket>>> call(NoParams params) async {
    buch.abrufe++;
    return Right([...buch.pakete]);
  }
}

class FakeHolePaket implements UseCase<Arbeitspaket, HoleArbeitspaketParams> {
  final PaketBuch buch;
  final List<HoleArbeitspaketParams> aufrufe = [];
  String? fehler;

  /// Der Dienst antwortet mit 409 — es ist nichts mehr offen. Eigener Schalter
  /// und eigener Failure-Typ, weil das kein Fehler ist, sondern das Ende.
  bool nichtsOffen = false;

  FakeHolePaket(this.buch);

  @override
  Future<Either<Failure, Arbeitspaket>> call(
    HoleArbeitspaketParams params,
  ) async {
    aufrufe.add(params);
    if (nichtsOffen) {
      return Left(
        KeinOffenerOrdnerFailure(
          message: 'Es ist kein Ordner mehr offen — es gibt nichts zu holen.',
        ),
      );
    }
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    return Right(buch.trageEin(params.ordnernamen, params.anzahl));
  }
}

class AufzeichnendeDatei
    implements UseCase<void, SchreibeArbeitspaketDateiParams> {
  final List<SchreibeArbeitspaketDateiParams> geschrieben = [];
  String? fehler;

  @override
  Future<Either<Failure, void>> call(
    SchreibeArbeitspaketDateiParams params,
  ) async {
    geschrieben.add(params);
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    return Right(null);
  }
}

void main() {
  late PaketBuch buch;
  late FakeHolePaket holen;
  late AufzeichnendeDatei schreiben;
  late ArbeitspaketCubit cubit;

  setUp(() {
    buch = PaketBuch();
    holen = FakeHolePaket(buch);
    schreiben = AufzeichnendeDatei();
    cubit = ArbeitspaketCubit(FesteArbeitspakete(buch), holen, schreiben);
  });

  tearDown(() => cubit.close());

  Future<Arbeitspaket?> holeZwei() => cubit.holeUndSchreibe(
    ordnernamen: const [
      'VUnfallursache Mark Schmidt',
      'Strafsache Eva Klein',
      'Buchhaltung 2019',
    ],
    anzahl: 2,
    zielPfad: r'C:\Pakete',
    mandanten: [mandant(1, 'Schmidt', vorname: 'Mark')],
  );

  test('Holen schreibt die Datei und lädt die Historie nach', () async {
    final paket = await holeZwei();

    expect(paket?.nummer, 1);
    expect(holen.aufrufe.single.anzahl, 2);
    expect(
      holen.aufrufe.single.ordnernamen,
      hasLength(3),
      reason:
          'Welche Ordner offen sind, entscheidet der Dienst — geschickt wird, '
          'was gescannt wurde.',
    );

    final datei = schreiben.geschrieben.single;
    expect(datei.pfad, endsWith('arbeitspaket-01.json'));
    expect(datei.pfad, startsWith(r'C:\Pakete'));

    final inhalt = jsonDecode(datei.inhalt) as Map<String, dynamic>;
    expect(inhalt['paket'], 1);
    expect((inhalt['ordner'] as List), hasLength(2));
    expect(inhalt['anleitung'], contains('GESCHLOSSEN'));
    expect((inhalt['bekannteMandanten'] as List).single, {
      'name': 'Mark Schmidt',
      'ordner': <String>[],
      'kennzeichen': <String>[],
    });

    // Die Stand-Anzeige muss das eben geholte Paket sofort zeigen — sonst
    // stünde dort „kein Paket" und im Explorer läge schon eines.
    expect(cubit.state.historie.single.nummer, 1);
    expect(cubit.state.neuestes?.nummer, 1);
    expect(cubit.state.offeneAnzahl, 1);
    expect(cubit.state.laufend, isFalse);
    expect(cubit.state.fehler, isNull);
  });

  test(
    'ein Fehler beim Holen landet im Zustand, geschrieben wird nichts',
    () async {
      holen.fehler = 'Es ist kein Ordner mehr offen.';

      final paket = await holeZwei();

      expect(paket, isNull);
      expect(schreiben.geschrieben, isEmpty);
      expect(cubit.state.fehler, 'Es ist kein Ordner mehr offen.');
      expect(cubit.state.laufend, isFalse);
      expect(cubit.state.historie, isEmpty);
    },
  );

  test('ein Fehler beim Schreiben lässt die Historie unangetastet', () async {
    schreiben.fehler = 'Der Ordner ist schreibgeschützt.';

    final paket = await holeZwei();

    expect(paket, isNull);
    expect(cubit.state.fehler, contains('schreibgeschützt'));
    expect(
      cubit.state.historie,
      isEmpty,
      reason:
          'Nachgeladen wird erst, wenn die Datei liegt — sonst behauptete die '
          'Anzeige ein Paket, das der Anwalt nirgends findet.',
    );
  });

  // Kein Fehler, sondern das Ende der Arbeit: Der Stapel ist leer. Stünde der
  // Satz in „fehler", meldete die Oberfläche einen Defekt für den Umstand,
  // dass der Anwalt fertig ist.
  test(
    'ist nichts mehr offen, steht das Merkmal statt eines Fehlers',
    () async {
      holen.nichtsOffen = true;

      final paket = await holeZwei();

      expect(paket, isNull);
      expect(cubit.state.nichtsOffen, isTrue);
      expect(cubit.state.fehler, isNull);
      expect(schreiben.geschrieben, isEmpty);
      expect(cubit.state.laufend, isFalse);
    },
  );

  test('ein neuer Versuch setzt das Merkmal zurück', () async {
    holen.nichtsOffen = true;
    await holeZwei();
    holen.nichtsOffen = false;

    final paket = await holeZwei();

    expect(paket?.nummer, 1);
    expect(cubit.state.nichtsOffen, isFalse);
  });

  test('Laden holt die Historie, neuestes zuerst', () async {
    buch.trageEin(const ['A'], 1);
    buch.trageEin(const ['B'], 1);

    await cubit.laden();

    expect([for (final p in cubit.state.historie) p.nummer], [2, 1]);
    expect(cubit.state.laufend, isFalse);
  });
}
