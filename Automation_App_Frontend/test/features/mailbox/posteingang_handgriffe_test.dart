import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_handgriffe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'posteingang_cubit_test.dart';

/// Reicht den `BuildContext` der Testseite nach außen — derselbe Aufbau wie
/// `rueckmeldung_test.dart`, denn `PosteingangHandgriffe._hole` zeigt seine
/// Meldung über `Rueckmeldung.von(context)`.
class KontextHalter extends StatelessWidget {
  const KontextHalter({super.key, required this.merken});

  final void Function(BuildContext context) merken;

  @override
  Widget build(BuildContext context) {
    merken(context);
    return const SizedBox.shrink();
  }
}

/// Deckt Befund 8 aus dem Review zu Issue #134 ab: `PosteingangHandgriffe`
/// las bislang `cubit.state.fehler` — ein Feld, das sich Seitenlade- und
/// Downloadfehler teilt. Ein alter Listenfehler blieb im Zustand stehen und
/// erschien dann fälschlich als Downloadfehler, sobald ein zweiter,
/// gleichzeitiger Downloadversuch nur mangels freier Verbindung scheiterte.
void main() {
  testWidgets('ein alter Listenfehler erscheint nicht als Downloadfehler', (
    tester,
  ) async {
    late BuildContext kontext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KontextHalter(merken: (c) => kontext = c)),
      ),
    );

    final repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final laden = cubit.aktualisieren();
    repo.seiten.last.completeError(
      const PosteingangFehler('Alter Listenfehler.'),
    );
    await laden;
    expect(cubit.state.fehler, 'Alter Listenfehler.');

    // Ein laufender Download besetzt `anhangLaedt` — der zweite Aufruf
    // scheitert dadurch, ohne dass ein echter Downloadfehler eintritt.
    const erster = PosteingangAnhang(id: '1', dateiname: 'a.pdf');
    const zweiter = PosteingangAnhang(id: '2', dateiname: 'b.pdf');
    final laeuft = cubit.anhangLaden('mail-1', erster);
    final handgriffe = PosteingangHandgriffe(cubit);

    await handgriffe.anhangOeffnen(kontext, 'mail-1', zweiter);
    await tester.pump();

    expect(find.text('Alter Listenfehler.'), findsNothing);
    expect(
      find.text(
        'Die Datei wird gerade schon geholt — bitte einen Augenblick '
        'warten.',
      ),
      findsOneWidget,
    );
    await laeuft;
  });
}
