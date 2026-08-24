import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFillOutTemplate
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  FillOutTemplateParams? letzteParams;

  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) async {
    letzteParams = params;
    return Right(
      GeneratedDocument(
        outputFilePath: r'C:\App\Generated\Arbeit\84-26 C03\Brief.docx',
        warnings: const ['Unbekannt'],
      ),
    );
  }
}

void main() {
  test(
    'EditDocumentEvent reicht die Vorgangsreferenz ans Backend durch',
    () async {
      final useCase = _FakeFillOutTemplate();
      final bloc = EditedDocumentBloc(useCase);

      bloc.add(
        const EditDocumentEvent(
          data: {'Name': 'Mustermann'},
          path: r'C:\Vorlagen\VORLAGE HGN.docx',
          outputFileName: 'VORLAGE HGN 12.06.2026',
          vorgangSchluessel: '84/26 C03_GG-XY 123',
        ),
      );
      await bloc.stream.firstWhere((state) => state is EditedDocumentLoaded);

      // Ohne den Schlüssel landeten alle Vorgänge in einem Ordner und
      // überschrieben einander.
      expect(useCase.letzteParams?.vorgangSchluessel, '84/26 C03_GG-XY 123');
    },
  );

  test('DokumentAbgelegtEvent schwenkt auf die Datei in der Akte um', () async {
    final bloc = EditedDocumentBloc(_FakeFillOutTemplate());

    bloc.add(
      const EditDocumentEvent(
        data: {'Name': 'Mustermann'},
        path: r'C:\Vorlagen\VORLAGE HGN.docx',
      ),
    );
    await bloc.stream.firstWhere((state) => state is EditedDocumentLoaded);

    bloc.add(
      const DokumentAbgelegtEvent(r'C:\Akten\Mustermann\Unfall\Brief.docx'),
    );
    final abgelegt =
        await bloc.stream.firstWhere(
              (state) =>
                  state is EditedDocumentLoaded &&
                  state.path.startsWith(r'C:\Akten'),
            )
            as EditedDocumentLoaded;

    // Der Arbeitsordner wird nach der Ablage gelöscht — ein Pfad dorthin
    // liefe ins Leere. Die Warnungen der Erzeugung gelten weiter.
    expect(abgelegt.path, r'C:\Akten\Mustermann\Unfall\Brief.docx');
    expect(abgelegt.warnings, ['Unbekannt']);
    // Daran erkennt die Seite, dass hier nichts erzeugt wurde: sonst schickt
    // ihr Listener den Anwalt aus dem Speicherschritt zurück ins Begutachten.
    expect(abgelegt.inAkteAbgelegt, isTrue);
  });

  test('ein frisch erzeugtes Dokument gilt nicht als abgelegt', () async {
    final bloc = EditedDocumentBloc(_FakeFillOutTemplate());

    bloc.add(
      const EditDocumentEvent(
        data: {'Name': 'Mustermann'},
        path: r'C:\Vorlagen\VORLAGE HGN.docx',
      ),
    );
    final erzeugt =
        await bloc.stream.firstWhere((state) => state is EditedDocumentLoaded)
            as EditedDocumentLoaded;

    expect(erzeugt.inAkteAbgelegt, isFalse);
  });

  test('DokumentAbgelegtEvent ohne erzeugtes Dokument ändert nichts', () async {
    final bloc = EditedDocumentBloc(_FakeFillOutTemplate());

    bloc.add(
      const DokumentAbgelegtEvent(r'C:\Akten\Mustermann\Unfall\Brief.docx'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, isA<EditedDocumentInitial>());
  });
}
