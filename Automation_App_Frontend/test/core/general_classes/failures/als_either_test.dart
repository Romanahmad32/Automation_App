import 'package:automation_app/core/general_classes/failures/als_either.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alsEither', () {
    test('verpackt den Erfolg als Right', () async {
      final ergebnis = await alsEither(() async => 42);

      expect(ergebnis, isA<Right<Failure, int>>());
      expect((ergebnis as Right<Failure, int>).value, 42);
    });

    test('verpackt eine Ausnahme ohne uebersetzen als ServerFailure ohne '
        'technisches Praefix', () async {
      final ergebnis = await alsEither<int>(
        () async => throw Exception('Etwas ging schief'),
      );

      expect(ergebnis, isA<Left<Failure, int>>());
      final failure = (ergebnis as Left<Failure, int>).value;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Etwas ging schief');
    });

    test(
      'nutzt uebersetzen, um den Failure-Typ und -Text selbst zu wählen',
      () async {
        final ergebnis = await alsEither<int>(
          () async => throw StateError('kaputt'),
          uebersetzen: (fehler) => LocalFailure(message: 'lokal: $fehler'),
        );

        final failure = (ergebnis as Left<Failure, int>).value;
        expect(failure, isA<LocalFailure>());
        expect(failure.message, contains('lokal:'));
      },
    );
  });
}
