import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vorgaenge/data/datasources/register_nummern_datasource.dart';
import 'package:automation_app/features/vorgaenge/data/repositories/register_nummern_repository_impl.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_nummern_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Merkt sich den zuletzt angefragten Jahrgang und liefert entweder einen
/// festen Stand oder wirft die hinterlegte [RegisterException].
class RegisterNummernDatasourceDouble implements RegisterNummernDatasource {
  final RegisterNummernStand? stand;
  final RegisterException? fehler;
  int? letzterJahrgang;

  RegisterNummernDatasourceDouble.mitStand(this.stand) : fehler = null;

  RegisterNummernDatasourceDouble.mitFehler(this.fehler) : stand = null;

  @override
  Future<RegisterNummernStand> ladeNummernstand({int? jahrgang}) async {
    letzterJahrgang = jahrgang;
    if (fehler != null) throw fehler!;
    return stand!;
  }
}

void main() {
  test('gibt den Nummernstand der Datasource unverändert weiter', () async {
    const erwartet = RegisterNummernStand(
      jahr: '2026',
      hoechsteNummer: 6,
      naechsteNummer: 7,
      belegte: [1, 4, 5, 6],
    );
    final datasource = RegisterNummernDatasourceDouble.mitStand(erwartet);
    final repository = RegisterNummernRepositoryImpl(datasource);

    final ergebnis = await repository.ladeNummernstand(jahrgang: 2026);

    expect(ergebnis, isA<Right<Failure, RegisterNummernStand>>());
    expect((ergebnis as Right<Failure, RegisterNummernStand>).value, erwartet);
    expect(datasource.letzterJahrgang, 2026);
  });

  test(
    'eine RegisterException der Datasource landet als ServerFailure ohne Praefix',
    () async {
      const nachricht =
          'Der Nummernstand des Registers konnte nicht geladen werden.';
      final datasource = RegisterNummernDatasourceDouble.mitFehler(
        const RegisterException(nachricht),
      );
      final repository = RegisterNummernRepositoryImpl(datasource);

      final ergebnis = await repository.ladeNummernstand();

      expect(ergebnis, isA<Left<Failure, RegisterNummernStand>>());
      final failure = (ergebnis as Left<Failure, RegisterNummernStand>).value;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, nachricht);
    },
  );
}
