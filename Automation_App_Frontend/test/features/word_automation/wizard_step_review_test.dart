import 'dart:typed_data';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/usecases/convert_docx_to_pdf.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liefert immer ein befülltes Dokument — damit stehen alle vier Knöpfe der
/// Zeile ("Zurück zum Ändern", "In Word öffnen", "Vorschau aktualisieren",
/// "Bestätigen") da. Bewusst ohne Warnungen: Der Warnhinweis über der
/// Vorschau hat eine eigene, unbeschränkte `Row` und damit ein eigenes,
/// hier nicht geprüftes Überlaufrisiko — dieser Test bleibt bei der
/// gemeldeten Knopfzeile.
class _StetsBefuellteVorlage
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) async => Right(
    const GeneratedDocument(outputFilePath: r'C:\fake\Anspruchsschreiben.docx'),
  );
}

/// Liefert ein befülltes Dokument mit Warnungen — reproduziert den
/// Warnhinweis-Banner (Issue #57): Seine Überschrift stand in einer `Row`
/// ohne `Expanded`/`Flexible` und lief bei "Am größten" und schmalem Fenster
/// rechts über.
class _VorlageMitWarnungen
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) async => Right(
    const GeneratedDocument(
      outputFilePath: r'C:\fake\Anspruchsschreiben.docx',
      warnings: [
        'Platzhalter {{Aktenzeichen_Gegenseite}} wurde nicht ersetzt',
        'Platzhalter {{Schadennummer_Versicherer}} wurde nicht ersetzt',
      ],
    ),
  );
}

/// Die Vorschau wird in diesem Test nie neu geladen — es geht um die
/// Knopfzeile darüber, nicht um das PDF selbst.
class _NieGeladenePdfVorschau
    implements UseCase<Uint8List, ConvertDocxToPdfParams> {
  @override
  Future<Either<Failure, Uint8List>> call(ConvertDocxToPdfParams params) =>
      throw UnimplementedError();
}

/// Die Knopfzeile unter der PDF-Vorschau (vier Knöpfe in einer `Row`) lief bei
/// der Schriftstufe „Am größten" (Issue #57) auf einem schmalen Fenster rechts
/// über — „Vorschau aktualisieren" war der engste Nachbar. Reproduziert wird
/// das mit dem echten `EditedDocumentBloc`, damit alle vier Knöpfe aktiv sind.
void main() {
  Future<void> zeigeSchritt(
    WidgetTester tester, {
    required double breite,
    UseCase<GeneratedDocument, FillOutTemplateParams>? vorlage,
  }) async {
    final editedDocumentBloc = EditedDocumentBloc(
      vorlage ?? _StetsBefuellteVorlage(),
    );
    addTearDown(editedDocumentBloc.close);
    final pdfPreviewBloc = ResultPdfPreviewBloc(_NieGeladenePdfVorschau());
    addTearDown(pdfPreviewBloc.close);

    editedDocumentBloc.add(
      const EditDocumentEvent(path: r'C:\fake\Vorlage.docx', data: {}),
    );

    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: editedDocumentBloc),
          BlocProvider.value(value: pdfPreviewBloc),
        ],
        child: MaterialApp(
          // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
          // bliebe der Test blind für den gemeldeten Überlauf.
          theme: MaterialTheme(
            ThemeData.light().textTheme,
            schriftstufe: Schriftstufe.amGroessten,
          ).light(),
          home: const Scaffold(body: WizardStepReview()),
        ),
      ),
    );
    // Bis der Bloc vom Initial- über den Ladezustand zum befüllten Dokument
    // durchgelaufen ist — erst dann stehen alle vier Knöpfe da.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'die Knopfzeile "Vorschau aktualisieren" laeuft bei "Am groessten" und '
    'schmalem Fenster nicht ueber',
    (tester) async {
      await zeigeSchritt(tester, breite: 700);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die vier Knöpfe unter der Vorschau ("Zurück zum Ändern", "In '
            'Word öffnen", "Vorschau aktualisieren", "Bestätigen") standen in '
            'einer Row ohne Wrap/Expanded — bei "Am größten" und schmalem '
            'Fenster lief die Zeile rechts über.',
      );
    },
  );

  testWidgets(
    'der Warnhinweis-Banner laeuft bei "Am groessten", schmalem Fenster und '
    'vorhandenen Warnungen nicht ueber',
    (tester) async {
      await zeigeSchritt(tester, breite: 500, vorlage: _VorlageMitWarnungen());

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die Überschrift des Warnhinweis-Banners ("Bitte prüfen — das '
            'Dokument enthält Warnungen:") stand in einer Row ohne '
            'Expanded/Flexible — bei "Am größten", schmalem Fenster und '
            'vorhandenen Warnungen lief sie rechts über.',
      );
    },
  );
}
