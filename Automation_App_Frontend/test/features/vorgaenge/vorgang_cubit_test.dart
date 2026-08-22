import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_json.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/referenz_vergeben_exception.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/services/wahrscheinlicher_vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-Memory-Ersatz für die Backend-Persistenz (Upsert/Delete pro Datensatz).
/// Bildet auch den atomaren Abschluss nach: Status und Auftragsnummer ändern
/// sich zusammen. Über [upsertSchlaegtFehl]/[abschliessenSchlaegtFehl] lassen
/// sich Backend-Ausfälle simulieren.
class _FakeVorgaengeDatasource implements VorgangRepository {
  List<Vorgang> vorgaenge = const [];
  int laufendeAuftragsnummer = 84;
  bool upsertSchlaegtFehl = false;
  bool abschliessenSchlaegtFehl = false;
  bool aendereReferenzSchlaegtFehl = false;

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;

  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async {
    if (upsertSchlaegtFehl) throw Exception('Backend nicht erreichbar');
    vorgaenge = [
      ...vorgaenge.where(
        (v) => !Vorgang.gleicheReferenz(v.referenz, vorgang.referenz),
      ),
      vorgang,
    ];
    return vorgang;
  }

  @override
  Future<void> deleteVorgang(String referenz) async {
    vorgaenge = vorgaenge
        .where((v) => !Vorgang.gleicheReferenz(v.referenz, referenz))
        .toList();
  }

  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async {
    if (aendereReferenzSchlaegtFehl) {
      throw Exception('Backend nicht erreichbar');
    }
    Vorgang? ziel;
    for (final v in vorgaenge) {
      if (Vorgang.gleicheReferenz(v.referenz, von)) {
        ziel = v;
      } else if (Vorgang.gleicheReferenz(v.referenz, nach)) {
        throw ReferenzVergebenException(nach);
      }
    }
    if (ziel == null) return null;
    final umbenannt = vorgangAusJson({...ziel.toJson(), 'referenz': nach});
    vorgaenge = [
      ...vorgaenge.where((v) => !Vorgang.gleicheReferenz(v.referenz, von)),
      umbenannt,
    ];
    return umbenannt;
  }

  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async {
    if (abschliessenSchlaegtFehl) throw Exception('Backend nicht erreichbar');
    for (final vorhanden in vorgaenge) {
      if (!Vorgang.gleicheReferenz(vorhanden.referenz, referenz)) continue;
      if (vorhanden.status == VorgangStatus.versendet) return vorhanden;
      final abgeschlossen = vorhanden.copyWith(
        status: VorgangStatus.versendet,
        abgeschlossenAm: DateTime.now(),
      );
      laufendeAuftragsnummer += 1;
      await upsertVorgang(abgeschlossen);
      return abgeschlossen;
    }
    return null;
  }
}

void main() {
  late _FakeVorgaengeDatasource datasource;
  late VorgangPersistenzFehlerCubit fehler;
  late VorgangCubit cubit;

  VorgangCubit baueCubit() => VorgangCubit(datasource, fehler);

  setUp(() {
    datasource = _FakeVorgaengeDatasource();
    fehler = VorgangPersistenzFehlerCubit();
    cubit = baueCubit();
  });

  tearDown(() async {
    await cubit.close();
    await fehler.close();
  });

  test('registriereAnfrage legt Vorgang an und persistiert ihn', () async {
    await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.status, VorgangStatus.angefragt);
    expect(datasource.vorgaenge, hasLength(1));
  });

  test('gleiche Referenz wird nicht doppelt geführt', () async {
    await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
    await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

    expect(cubit.state, hasLength(1));
  });

  test(
    'uebernehmeAntwort ordnet über die Referenz zu und schaltet weiter',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      await cubit.uebernehmeAntwort(
        const ZentralrufReplyData(
          referenz: '84/26  c03_gg-xy 123',
          versichererName: 'HUK',
        ),
      );

      expect(cubit.state, hasLength(1));
      expect(cubit.state.single.status, VorgangStatus.beantwortet);
      expect(cubit.state.single.gegner, 'HUK');
    },
  );

  test(
    'uebernehmeAntwort ohne passende Anfrage legt eigenen Vorgang an',
    () async {
      await cubit.uebernehmeAntwort(
        const ZentralrufReplyData(
          referenz: '99/26 C03_HG-X 9',
          versichererName: 'Allianz',
        ),
      );

      expect(cubit.state, hasLength(1));
      final vorgang = cubit.state.single;
      expect(vorgang.referenz, '99/26 C03_HG-X 9');
      expect(vorgang.status, VorgangStatus.beantwortet);
      expect(vorgang.gegner, 'Allianz');
      expect(datasource.vorgaenge, hasLength(1));
    },
  );

  test('uebernehmeAntwort ordnet bei abweichender Zielreferenz dem gewählten '
      'Vorgang zu', () async {
    await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
    await cubit.registriereAnfrage('99/26 C03_HG-X 9');

    // Die Antwort trägt die Referenz von Vorgang A, der Anwalt ordnet sie aber
    // manuell Vorgang B zu (korrigierte/abweichende Auto-Zuordnung).
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(
        referenz: '84/26 C03_GG-XY 123',
        versichererName: 'HUK',
      ),
      zielReferenz: '99/26 c03_hg-x 9',
    );

    // Kein neuer Vorgang; die Antwort liegt in B, A bleibt unberührt.
    expect(cubit.state, hasLength(2));
    final a = cubit.findeZuReferenz('84/26 C03_GG-XY 123')!;
    final b = cubit.findeZuReferenz('99/26 C03_HG-X 9')!;
    expect(a.antwort, isNull);
    expect(a.status, VorgangStatus.angefragt);
    expect(b.antwort, isNotNull);
    expect(b.gegner, 'HUK');
    expect(b.status, VorgangStatus.beantwortet);
  });

  test('uebernehmeAntwort ohne Referenz legt pro Antwort einen eigenen '
      'Vorgang an (keine Kollision)', () async {
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(versichererName: 'HUK'),
    );
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(versichererName: 'Allianz'),
    );

    // Die zweite referenzlose Antwort darf die erste nicht überschreiben.
    expect(cubit.state, hasLength(2));
    final referenzen = cubit.state.map((v) => v.referenz).toSet();
    expect(referenzen, hasLength(2));
    expect(cubit.state.map((v) => v.gegner).toSet(), {'HUK', 'Allianz'});
  });

  test('uebernehmeAntwort legt unter unbekannter Zielreferenz einen neuen '
      'Vorgang mit genau dieser Referenz an', () async {
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(
        referenz: '84/26 C03_GG-XY 123',
        versichererName: 'HUK',
      ),
      zielReferenz: '77/26 C03_HG-E 1427',
    );

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.referenz, '77/26 C03_HG-E 1427');
    expect(cubit.state.single.gegner, 'HUK');
  });

  test(
    'uebernehmeAntwort mit leerer Zielreferenz nutzt die Antwort-Referenz',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

      await cubit.uebernehmeAntwort(
        const ZentralrufReplyData(
          referenz: '84/26 C03_GG-XY 123',
          versichererName: 'HUK',
        ),
        zielReferenz: '',
      );

      expect(cubit.state, hasLength(1));
      expect(cubit.state.single.status, VorgangStatus.beantwortet);
    },
  );

  test(
    'findeZuReferenz ist tolerant bei Schreibweise und Whitespace',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

      expect(cubit.findeZuReferenz('84/26  c03_gg-xy 123 '), isNotNull);
      expect(cubit.findeZuReferenz('85/26 C03_GG-XY 123'), isNull);
      expect(cubit.findeZuReferenz(null), isNull);
    },
  );

  test('findeWahrscheinlichenVorgang findet den angefragten Vorgang über '
      'Kennzeichen und Unfalldatum (verstümmelte Referenz)', () async {
    await cubit.registriereAnfrage(
      '84/26 C03_GG-XY 123',
      unfallDatum: '01.06.2026',
    );

    final vermutet = findeWahrscheinlichenVorgang(
      cubit.state,
      const ZentralrufReplyData(
        referenz: '84/2 C03_GG-XY 12', // in der Mail verstümmelt
        kennzeichen: 'gg-xy123', // Schreibvariante
        unfallDatum: '01.06.2026',
      ),
    );

    expect(vermutet, isNotNull);
    expect(vermutet!.referenz, '84/26 C03_GG-XY 123');
  });

  test('findeWahrscheinlichenVorgang liefert nichts, wenn die Referenz schon '
      'passt (exakter Treffer hat Vorrang)', () async {
    await cubit.registriereAnfrage(
      '84/26 C03_GG-XY 123',
      unfallDatum: '01.06.2026',
    );

    final vermutet = findeWahrscheinlichenVorgang(
      cubit.state,
      const ZentralrufReplyData(
        referenz: '84/26 C03_GG-XY 123',
        kennzeichen: 'GG-XY 123',
        unfallDatum: '01.06.2026',
      ),
    );

    expect(vermutet, isNull);
  });

  test(
    'findeWahrscheinlichenVorgang liefert bei mehrdeutigen Treffern nichts',
    () async {
      await cubit.registriereAnfrage(
        '84/26 C03_GG-XY 123',
        unfallDatum: '01.06.2026',
      );
      await cubit.registriereAnfrage(
        '85/26 C03_GG-XY 123',
        unfallDatum: '01.06.2026',
      );

      final vermutet = findeWahrscheinlichenVorgang(
        cubit.state,
        const ZentralrufReplyData(
          kennzeichen: 'GG-XY 123',
          unfallDatum: '01.06.2026',
        ),
      );

      expect(vermutet, isNull);
    },
  );

  test(
    'findeWahrscheinlichenVorgang ignoriert bereits beantwortete Vorgänge',
    () async {
      await cubit.registriereAnfrage(
        '84/26 C03_GG-XY 123',
        unfallDatum: '01.06.2026',
      );
      await cubit.uebernehmeAntwort(
        const ZentralrufReplyData(
          referenz: '84/26 C03_GG-XY 123',
          versichererName: 'HUK',
        ),
      );

      final vermutet = findeWahrscheinlichenVorgang(
        cubit.state,
        const ZentralrufReplyData(
          kennzeichen: 'GG-XY 123',
          unfallDatum: '01.06.2026',
        ),
      );

      expect(vermutet, isNull);
    },
  );

  test(
    'findeWahrscheinlichenVorgang braucht Kennzeichen und Unfalldatum',
    () async {
      await cubit.registriereAnfrage(
        '84/26 C03_GG-XY 123',
        unfallDatum: '01.06.2026',
      );

      expect(
        findeWahrscheinlichenVorgang(
          cubit.state,
          const ZentralrufReplyData(kennzeichen: 'GG-XY 123'),
        ),
        isNull,
      );
      expect(
        findeWahrscheinlichenVorgang(
          cubit.state,
          const ZentralrufReplyData(unfallDatum: '01.06.2026'),
        ),
        isNull,
      );
    },
  );

  test('stellt persistierte Vorgänge beim Erzeugen wieder her', () async {
    datasource.vorgaenge = [
      Vorgang.ausAnfrage(
        referenz: '12/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 1),
      ),
    ];

    final restored = baueCubit();
    // ladeErneut läuft asynchron im Konstruktor an.
    await Future<void>.delayed(Duration.zero);

    expect(restored.state, hasLength(1));
    expect(restored.findeZuReferenz('12/26 C03_HG-E 1427'), isNotNull);
    await restored.close();
  });

  test(
    'abschliessen schaltet auf versendet und zählt die Nummer hoch',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

      final erfolgreich = await cubit.abschliessen(cubit.state.single);

      expect(erfolgreich, isTrue);
      final abgeschlossen = cubit.findeZuReferenz('84/26 C03_GG-XY 123')!;
      expect(abgeschlossen.status, VorgangStatus.versendet);
      expect(abgeschlossen.abgeschlossenAm, isNotNull);
      expect(datasource.laufendeAuftragsnummer, 85);
    },
  );

  test(
    'abschliessen zählt einen bereits versendeten Vorgang nicht erneut hoch',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      await cubit.abschliessen(cubit.state.single);
      expect(datasource.laufendeAuftragsnummer, 85);

      // Erneuter Aufruf darf die Nummer nicht weiter erhöhen.
      await cubit.abschliessen(cubit.state.single);
      expect(datasource.laufendeAuftragsnummer, 85);
    },
  );

  test(
    'abschliessen lässt bei Backend-Fehler Status und Nummer unverändert',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      datasource.abschliessenSchlaegtFehl = true;

      final erfolgreich = await cubit.abschliessen(cubit.state.single);

      expect(erfolgreich, isFalse);
      expect(cubit.state.single.status, VorgangStatus.angefragt);
      expect(datasource.laufendeAuftragsnummer, 84);
    },
  );

  test(
    'aendereReferenz benennt den Vorgang um und behält seine Daten',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      await cubit.uebernehmeAntwort(
        const ZentralrufReplyData(
          referenz: '84/26 C03_GG-XY 123',
          versichererName: 'HUK',
        ),
      );

      final ergebnis = await cubit.aendereReferenz(
        cubit.state.single,
        '85/26 C03_GG-XY 312',
      );

      expect(ergebnis.fehler, isNull);
      expect(ergebnis.vorgang!.referenz, '85/26 C03_GG-XY 312');
      expect(cubit.state, hasLength(1));
      expect(cubit.findeZuReferenz('84/26 C03_GG-XY 123'), isNull);
      final umbenannt = cubit.findeZuReferenz('85/26 C03_GG-XY 312')!;
      expect(umbenannt.gegner, 'HUK');
      expect(umbenannt.status, VorgangStatus.beantwortet);
      expect(datasource.vorgaenge.single.referenz, '85/26 C03_GG-XY 312');
    },
  );

  test(
    'aendereReferenz weist eine bereits vergebene Zielreferenz ab',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      await cubit.registriereAnfrage('85/26 C03_HG-E 1427');

      final ergebnis = await cubit.aendereReferenz(
        cubit.findeZuReferenz('84/26 C03_GG-XY 123')!,
        '85/26 c03_hg-e 1427',
      );

      expect(ergebnis.vorgang, isNull);
      expect(ergebnis.fehler, contains('bereits einem anderen Vorgang'));
      // Beide Vorgänge bleiben unverändert bestehen.
      expect(cubit.state, hasLength(2));
      expect(cubit.findeZuReferenz('84/26 C03_GG-XY 123'), isNotNull);
    },
  );

  test(
    'aendereReferenz meldet Backend-Fehler statt den State zu ändern',
    () async {
      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
      datasource.aendereReferenzSchlaegtFehl = true;

      final ergebnis = await cubit.aendereReferenz(
        cubit.state.single,
        '85/26 C03_GG-XY 123',
      );

      expect(ergebnis.vorgang, isNull);
      expect(ergebnis.fehler, isNotNull);
      expect(cubit.state.single.referenz, '84/26 C03_GG-XY 123');
    },
  );

  test(
    'fehlgeschlagenes Speichern wird gemeldet statt still geschluckt',
    () async {
      datasource.upsertSchlaegtFehl = true;

      await cubit.registriereAnfrage('84/26 C03_GG-XY 123');

      // In-Memory bleibt der Vorgang erhalten, der Fehler ist gemeldet.
      expect(cubit.state, hasLength(1));
      expect(fehler.state, isNotNull);
      expect(fehler.state!.aktion, VorgangPersistenzAktion.speichern);
      expect(fehler.state!.vorgang?.referenz, '84/26 C03_GG-XY 123');
    },
  );

  test('wiederhole speichert einen gemeldeten Vorgang nachträglich', () async {
    datasource.upsertSchlaegtFehl = true;
    await cubit.registriereAnfrage('84/26 C03_GG-XY 123');
    final gemeldet = fehler.state!;

    datasource.upsertSchlaegtFehl = false;
    await cubit.wiederhole(gemeldet);

    expect(datasource.vorgaenge, hasLength(1));
    expect(datasource.vorgaenge.single.referenz, '84/26 C03_GG-XY 123');
  });
}
