import 'dart:async';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class PosteingangTestRepository implements PosteingangRepository {
  final aufrufe = <String?>[];
  final inhalte = <String, Completer<PosteingangInhalt>>{};
  final seiten = <Completer<PosteingangSeite>>[];
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
    repo.inhalte['b']!.complete(const PosteingangInhalt('Text B', false, []));
    await neu;
    repo.inhalte['a']!.complete(const PosteingangInhalt('Text A', false, []));
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
}
