import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandant_edit_cubit/mandant_edit_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/pages/mandant_details_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class NieAufrufenderAnlegen implements UseCase<Mandant, CreateMandantRequest> {
  @override
  Future<Either<Failure, Mandant>> call(CreateMandantRequest params) =>
      throw UnimplementedError();
}

class NieAufrufenderAendern implements UseCase<Mandant, Mandant> {
  @override
  Future<Either<Failure, Mandant>> call(Mandant params) =>
      throw UnimplementedError();
}

/// Auf dem Desktop hängt der `PrimaryScrollController` nicht an einer
/// `SingleChildScrollView`; eine `Scrollbar` ohne eigenen Controller wirft dann
/// beim ersten Scrollen eine Assertion — im Debug-Build, den der Anwalt nicht
/// sieht, den die E2E-Suite aber trifft.
void main() {
  testWidgets(
    'Neuer Mandant lässt sich auf dem Desktop scrollen, ohne dass die '
    'Bildlaufleiste eine Assertion wirft',
    (tester) async {
      tester.view.physicalSize = const Size(900, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => MandantEditCubit(
              NieAufrufenderAnlegen(),
              NieAufrufenderAendern(),
            ),
            child: const MandantDetailsPage(),
          ),
        ),
      );
      await tester.pump();

      final scrollable = find.byType(Scrollable).first;
      final vorher = tester.state<ScrollableState>(scrollable).position.pixels;

      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(vorher),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
