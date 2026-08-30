import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Steuerbare Attrappe: Jeder Aufruf legt einen Completer ab, der Test
/// entscheidet, wann und womit geantwortet wird — so lässt sich das schnelle
/// Hin- und Herschalten zwischen zwei Dateien nachstellen.
class GesteuerteTemplatePlaceholders
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  final aufrufe = <String, Completer<Either<Failure, List<String>>>>{};

  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) {
    final completer = Completer<Either<Failure, List<String>>>();
    aufrufe[params.wordFilePath] = completer;
    return completer.future;
  }

  void antworte(String pfad, List<String> platzhalter) =>
      aufrufe[pfad]!.complete(Right(platzhalter));

  void scheitere(String pfad) =>
      aufrufe[pfad]!.complete(Left(ServerFailure(message: 'Datei gesperrt')));
}

void main() {
  test('liefert die Platzhalter der geladenen Datei', () async {
    final usecase = GesteuerteTemplatePlaceholders();
    final cubit = AktivePlatzhalterCubit(usecase);

    final laden = cubit.lade(r'C:\Vorlagen\hgn.docx');
    expect(cubit.state.pfad, r'C:\Vorlagen\hgn.docx');
    expect(cubit.state.platzhalter, isNull, reason: 'noch nichts bekannt');

    usecase.antworte(r'C:\Vorlagen\hgn.docx', ['Kennzeichen', 'Frist']);
    await laden;

    expect(cubit.state.platzhalter, {'Kennzeichen', 'Frist'});
    expect(cubit.state.fehlgeschlagen, isFalse);
  });

  test('ein Fehler hinterlässt „nichts bekannt", als fehlgeschlagen '
      'markiert', () async {
    final usecase = GesteuerteTemplatePlaceholders();
    final cubit = AktivePlatzhalterCubit(usecase);

    final laden = cubit.lade(r'C:\Vorlagen\hgn.docx');
    usecase.scheitere(r'C:\Vorlagen\hgn.docx');
    await laden;

    expect(cubit.state.platzhalter, isNull);
    expect(cubit.state.fehlgeschlagen, isTrue);
  });

  test('die Antwort einer abgewählten Datei wird verworfen', () async {
    final usecase = GesteuerteTemplatePlaceholders();
    final cubit = AktivePlatzhalterCubit(usecase);

    final erste = cubit.lade(r'C:\Vorlagen\hgn.docx');
    final zweite = cubit.lade(r'C:\Vorlagen\auflistung.docx');

    // Die alte Antwort trifft ein, nachdem längst umgeschaltet wurde.
    usecase.antworte(r'C:\Vorlagen\hgn.docx', ['Kennzeichen']);
    await erste;
    expect(cubit.state.pfad, r'C:\Vorlagen\auflistung.docx');
    expect(cubit.state.platzhalter, isNull);

    usecase.antworte(r'C:\Vorlagen\auflistung.docx', ['Schadensaufstellung']);
    await zweite;
    expect(cubit.state.platzhalter, {'Schadensaufstellung'});
  });
}
