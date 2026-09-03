import 'package:automation_app/core/general_widgets/form/hinzufuegen_button.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/grussformeln_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/settings/presentation/widgets/anredebausteine_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/grussformeln_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// „Hinzufügen" ist eine **Handlung**, kein Eintrag (§7.1).
///
/// Beide Abschnitte trugen den Knopf als `ActionChip` in derselben Reihe wie
/// die Einträge und mit derselben Umrandung wie sie. „+ Anrede hinzufügen"
/// stand damit neben „Sehr geehrter" und „Guten Tag" und sah aus wie eine
/// dritte Anrede — mit dem Unterschied, dass ein Klick darauf etwas ganz
/// anderes tut als ein Klick auf die Nachbarn.
///
/// Der Knopf gehört deshalb **unter** die Liste und in eine andere Bauform:
/// [HinzufuegenButton]. Was etwas tut, sieht anders aus als das, woran es
/// etwas tut.
class FakeAnredebausteineRepository implements AnredebausteineRepository {
  FakeAnredebausteineRepository(this.bestand);

  final List<Anredebaustein> bestand;

  @override
  Future<List<Anredebaustein>> ladeAnredebausteine() async => bestand;

  @override
  Future<Anredebaustein> lege(Anredebaustein baustein) async => baustein;

  @override
  Future<Anredebaustein> aktualisiere(Anredebaustein baustein) async =>
      baustein;

  @override
  Future<void> loesche(int id) async {}
}

class FakeGrussformelnRepository implements GrussformelnRepository {
  FakeGrussformelnRepository(this.bestand);

  final List<Grussformel> bestand;

  @override
  Future<List<Grussformel>> ladeGrussformeln() async => bestand;

  @override
  Future<Grussformel> lege(Grussformel grussformel) async => grussformel;

  @override
  Future<Grussformel> aktualisiere(Grussformel grussformel) async =>
      grussformel;

  @override
  Future<void> loesche(int id) async {}
}

void main() {
  // Der Typ muss mitwandern: `BlocProvider.value` leitet ihn aus dem
  // statischen Typ ab, und ein `dynamic` liefert einen Provider, den der
  // Abschnitt darüber nicht findet.
  Future<void> zeige<C extends StateStreamableSource<Object?>>(
    WidgetTester tester,
    Widget inhalt,
    C cubit,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<C>.value(value: cubit, child: inhalt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('die Anreden trennen Handlung und Bestand', (tester) async {
    final cubit = AnredebausteineCubit(
      FakeAnredebausteineRepository(const [
        Anredebaustein(
          id: 1,
          maennlich: 'Sehr geehrter',
          weiblich: 'Sehr geehrte',
          neutral: 'Sehr geehrte',
        ),
      ]),
    );
    await cubit.laden();
    await zeige(tester, const AnredebausteineSektionInhalt(), cubit);

    // Der Knopf ist ein Knopf …
    expect(
      find.widgetWithText(HinzufuegenButton, 'Anrede hinzufügen'),
      findsOneWidget,
    );
    // … und kein Chip: Was hinzufügt, steht nicht in der Reihe der Einträge.
    expect(find.byType(ActionChip), findsNothing);
    expect(find.widgetWithText(InputChip, 'Anrede hinzufügen'), findsNothing);

    // Der Bestand selbst bleibt, was er war.
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('die Zusatzgrüße trennen Handlung und Bestand', (tester) async {
    final cubit = GrussformelnCubit(
      FakeGrussformelnRepository(const [Grussformel(id: 1, text: 'Schalom')]),
    );
    await cubit.laden();
    await zeige(tester, const GrussformelnSektionInhalt(), cubit);

    expect(
      find.widgetWithText(HinzufuegenButton, 'Gruß hinzufügen'),
      findsOneWidget,
    );
    expect(find.byType(ActionChip), findsNothing);
    expect(find.widgetWithText(InputChip, 'Schalom'), findsOneWidget);
  });

  testWidgets('ohne Eintrag bleibt der Knopf und die Reihe entfällt', (
    tester,
  ) async {
    final cubit = GrussformelnCubit(FakeGrussformelnRepository(const []));
    await cubit.laden();
    await zeige(tester, const GrussformelnSektionInhalt(), cubit);

    expect(find.byType(HinzufuegenButton), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });
}
