import 'dart:async';

import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:automation_app/features/mailbox/domain/services/vorgangsbezug_erkenner.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

class PosteingangTestRepository implements PosteingangRepository {
  /// Das gespielte Zwischenlager des Dienstes — die Pfade führen nirgendwohin,
  /// gebraucht wird nur, dass es welche sind.
  static const String lager = 'C:/lager/posteingang';

  final aufrufe = <String?>[];
  final inhalte = <String, Completer<PosteingangInhalt>>{};
  final seiten = <Completer<PosteingangSeite>>[];

  /// Was der Cubit an Dateien angefordert hat — `id` bzw. `id/anhangId`.
  final downloads = <String>[];
  int abbrueche = 0;
  @override
  Future<PosteingangSeite> ladeSeite({String? cursor}) {
    aufrufe.add(cursor);
    final result = Completer<PosteingangSeite>();
    seiten.add(result);
    return result.future;
  }

  @override
  Future<PosteingangInhalt> ladeInhalt(String id) =>
      (inhalte[id] = Completer<PosteingangInhalt>()).future;

  @override
  Future<PosteingangAnhangAblage> ladeAnhang(String id, String anhangId) async {
    downloads.add('$id/$anhangId');
    final name = 'Anhang $anhangId.pdf';
    return PosteingangAnhangAblage(dateiname: name, pfad: '$lager/$name');
  }

  @override
  Future<PosteingangAnhangAblage> ladeEml(String id) async {
    downloads.add(id);
    return PosteingangAnhangAblage(
      dateiname: '$id.eml',
      pfad: '$lager/$id.eml',
    );
  }

  @override
  void abbrechen() => abbrueche++;
}

class PosteingangTestPush implements MailboxPushNotifier {
  @override
  Stream<void> get onPosteingangChanged => const Stream.empty();
  @override
  Stream<void> get onReplyReceived => const Stream.empty();
  @override
  Stream<void> get onStatusChanged => const Stream.empty();
  @override
  Future<void> ensureConnected() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  const a = PosteingangEintrag(id: 'a', betreff: 'A', absender: 'A');
  const b = PosteingangEintrag(id: 'b', betreff: 'B', absender: 'B');

  test('Blättern ersetzt die Seite und lädt keinen Mailtext vorab', () async {
    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final laden = cubit.aktualisieren();
    repo.seiten.last.complete(const PosteingangSeite([a], 'weiter', 10000));
    await laden;
    final weiter = cubit.aeltere();
    await cubit.aeltere(); // Doppelklick erzeugt keinen zweiten Abruf.
    expect(repo.aufrufe, [null, 'weiter']);
    repo.seiten.last.complete(const PosteingangSeite([b], null, 10000));
    await weiter;
    expect(cubit.state.seite!.nachrichten, [b]);
    expect(cubit.state.seitennummer, 2);
    expect(repo.inhalte, isEmpty);
  });

  test('Verspäteter Mailtext überschreibt die neue Auswahl nicht', () async {
    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final alt = cubit.oeffnen(a);
    final neu = cubit.oeffnen(b);
    repo.inhalte['b']!.complete(const PosteingangInhalt(text: 'Text B'));
    await neu;
    repo.inhalte['a']!.complete(const PosteingangInhalt(text: 'Text A'));
    await alt;
    expect(cubit.state.auswahl, b);
    expect(cubit.state.inhalt!.text, 'Text B');
  });

  test('Veraltete Seitenantwort überschreibt Aktualisierung nicht', () async {
    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final alt = cubit.aktualisieren();
    final neu = cubit.aktualisieren();
    repo.seiten.last.complete(const PosteingangSeite([b], null, 1));
    await neu;
    repo.seiten.first.complete(const PosteingangSeite([a], null, 1));
    await alt;
    expect(cubit.state.seite!.nachrichten, [b]);
    expect(repo.abbrueche, 2);
  });

  test(
    'Fehler beim Blättern bewahrt Seite und Position für Wiederholung',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(const PosteingangSeite([a], 'weiter', 100));
      await laden;
      final weiter = cubit.aeltere();
      repo.seiten.last.completeError(
        const PosteingangFehler('Keine Verbindung'),
      );
      await weiter;
      expect(cubit.state.seitennummer, 1);
      expect(cubit.state.seite!.nachrichten, [a]);
      expect(cubit.state.fehler, 'Keine Verbindung');
    },
  );

  // Ab hier: Erweiterungen zu Issue #134 (Anhängen, Deckel, Filter, Zähler,
  // Vorgangsbezug, Zentralruf-Markierung, Downloads). Die Tests oben bleiben
  // unverändert stehen.

  test(
    'Ältere Seite wird angehängt, "seite" bleibt die zuletzt geholte',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(const PosteingangSeite([a], 'weiter', 3));
      await laden;
      final weiter = cubit.aeltere();
      repo.seiten.last.complete(const PosteingangSeite([b], null, 3));
      await weiter;
      expect(cubit.state.eintraege, [a, b]);
      expect(cubit.state.seite!.nachrichten, [b]);
    },
  );

  test('Neu laden ersetzt die angehängte Liste wieder von vorn', () async {
    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final erste = cubit.aktualisieren();
    repo.seiten.last.complete(const PosteingangSeite([a], 'weiter', 3));
    await erste;
    final aelter = cubit.aeltere();
    repo.seiten.last.complete(const PosteingangSeite([b], null, 3));
    await aelter;
    final neu = cubit.aktualisieren();
    repo.seiten.last.complete(const PosteingangSeite([a], 'weiter', 3));
    await neu;
    expect(cubit.state.eintraege, [a]);
  });

  test(
    'Deckel bei 500 Einträgen (Entscheidung 8.2) stoppt weiteres Anhängen',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      final ersteSeite = List.generate(
        490,
        (i) => PosteingangEintrag(id: 'e$i', betreff: 'B', absender: 'A'),
      );
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(PosteingangSeite(ersteSeite, 'weiter', 1000));
      await laden;
      expect(cubit.state.alleGeladen, isFalse);

      final zweiteSeite = List.generate(
        50,
        (i) => PosteingangEintrag(id: 'f$i', betreff: 'B', absender: 'A'),
      );
      final weiter = cubit.aeltere();
      repo.seiten.last.complete(
        PosteingangSeite(zweiteSeite, 'nochWeiter', 1000),
      );
      await weiter;
      expect(cubit.state.eintraege, hasLength(500));
      expect(cubit.state.alleGeladen, isTrue);

      // Der Deckel greift beim Anhängen — nicht beim Abrufen selbst: ein
      // weiterer Versuch löst also gar keinen Abruf mehr aus.
      await cubit.aeltere();
      expect(repo.aufrufe, [null, 'weiter']);
    },
  );

  test(
    'Filter zeigt nur den passenden Ausschnitt, Zähler zählt Zentralruf-Zeilen',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      const mitSchluessel = PosteingangEintrag(
        id: 'mv',
        betreff: 'X',
        absender: 'A',
        messageId: 'Msg-1',
      );
      const ohneSchluessel = PosteingangEintrag(
        id: 'ob',
        betreff: 'Y',
        absender: 'B',
      );
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(
        const PosteingangSeite([mitSchluessel, ohneSchluessel], null, 2),
      );
      await laden;

      cubit.merkeZentralruf(['msg-1']);
      expect(cubit.state.zentralrufAnzahl, 1);
      expect(cubit.state.zentralrufFuer('Msg-1'), isFalse); // offen

      cubit.setzeFilter(PosteingangFilter.zentralruf);
      expect(cubit.state.sichtbar, [mitSchluessel]);

      // Verschwindet ein zuvor offener Schlüssel aus der nächsten Meldung,
      // gilt er als übernommen statt als "kein Bezug mehr".
      cubit.merkeZentralruf(const <String>[]);
      expect(cubit.state.zentralrufFuer('Msg-1'), isTrue); // übernommen
      expect(cubit.state.zentralrufAnzahl, 1);
    },
  );

  test(
    'bezuegeNeuRechnen erkennt den Vorgang; "Nicht zuordnen" gilt nur für die '
    'Sitzung und lässt den Vorgang unberührt',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      final vorgang = Vorgang.ausAnfrage(
        referenz: '144/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 9, 1),
      );
      const mail = PosteingangEintrag(
        id: 'mit-zeichen',
        betreff: 'Unser Zeichen: 144/26 C03',
        absender: 'A',
      );
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(const PosteingangSeite([mail], null, 1));
      await laden;

      cubit.bezuegeNeuRechnen(VorgangsbezugErkenner(vorgaenge: [vorgang]));
      expect(
        cubit.state.bezugFuer('mit-zeichen')?.vorgang.referenz,
        vorgang.referenz,
      );

      cubit.nichtZuordnen('mit-zeichen');
      expect(cubit.state.bezugFuer('mit-zeichen'), isNull);
      expect(
        cubit.state.bezuege['mit-zeichen']?.vorgang.referenz,
        vorgang.referenz,
        reason: '"Nicht zuordnen" blendet nur aus, ändert nichts am Vorgang.',
      );
    },
  );

  test(
    'anhangLaden liefert den Pfad und setzt anhangLaedt kurzzeitig',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      const anhang = PosteingangAnhang(id: '2', dateiname: 'Anlage.pdf');
      final laufend = cubit.anhangLaden('mail-1', anhang);
      expect(cubit.state.anhangLaedt, isTrue);
      final pfad = await laufend;
      expect(pfad, '${PosteingangTestRepository.lager}/Anhang 2.pdf');
      expect(cubit.state.anhangLaedt, isFalse);
      expect(repo.downloads, ['mail-1/2']);
    },
  );

  test('emlLaden liefert den Pfad der ganzen Nachricht', () async {
    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final pfad = await cubit.emlLaden('mail-1');
    expect(pfad, '${PosteingangTestRepository.lager}/mail-1.eml');
    expect(repo.downloads, ['mail-1']);
  });

  test(
    'ein zweiter Download während eines laufenden liefert sofort null',
    () async {
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      const anhang = PosteingangAnhang(id: '2', dateiname: 'A.pdf');
      final erster = cubit.anhangLaden('mail-1', anhang);
      final zweiter = cubit.emlLaden('mail-1');
      expect(await zweiter, isNull);
      await erster;
    },
  );
}
