import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/usecases/convert_docx_to_pdf.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'pdf_preview_event.dart';
part 'pdf_preview_state.dart';

/// Lädt die originalgetreue PDF-Vorschau eines DOCX über das Backend
/// (Word-Konvertierung, serverseitig gecacht). Wird zweimal eingesetzt:
/// als [TemplatePdfPreviewBloc] (Vorlage, Schritt 1) und als
/// [ResultPdfPreviewBloc] (ausgefülltes Dokument, Schritt 3).
abstract class PdfPreviewBloc extends Bloc<PdfPreviewEvent, PdfPreviewState> {
  final UseCase<Uint8List, ConvertDocxToPdfParams> convertDocxToPdf;

  /// Zählt die Ladevorgänge hoch, damit der PDF-Viewer auch bei gleichem
  /// Dateipfad (z. B. nach "Vorschau aktualisieren") neu rendert.
  int _loadCounter = 0;

  PdfPreviewBloc(this.convertDocxToPdf) : super(PdfPreviewInitial()) {
    // restartable: Eine neue Vorlagenauswahl bricht den vorherigen, noch
    // laufenden Ladevorgang ab. So kann eine verspätet eintreffende Antwort
    // einer früheren Auswahl nicht mehr die aktuelle Vorschau überschreiben.
    on<LoadPdfPreviewEvent>(_onLoadPdfPreview, transformer: restartable());
  }

  Future<void> _onLoadPdfPreview(
    LoadPdfPreviewEvent event,
    Emitter<PdfPreviewState> emit,
  ) async {
    emit(PdfPreviewLoading());

    final result = await convertDocxToPdf(
      ConvertDocxToPdfParams(docxFilePath: event.docxFilePath),
    );

    // Wenn restartable() diesen Handler wegen einer neuen Auswahl abgebrochen
    // hat, ist der Emitter geschlossen – die Antwort gehört zu einer veralteten
    // Auswahl und darf die Vorschau nicht mehr überschreiben.
    if (emit.isDone) {
      return;
    }

    switch (result) {
      case Left(value: final failure):
        emit(PdfPreviewError(failure.message));
      case Right(value: final pdfBytes):
        _loadCounter++;
        final sourceName = '${event.docxFilePath}#v$_loadCounter';
        emit(PdfPreviewLoaded(pdfBytes: pdfBytes, sourceName: sourceName));
    }
  }
}

@injectable
class TemplatePdfPreviewBloc extends PdfPreviewBloc {
  TemplatePdfPreviewBloc(super.convertDocxToPdf);
}

@injectable
class ResultPdfPreviewBloc extends PdfPreviewBloc {
  ResultPdfPreviewBloc(super.convertDocxToPdf);
}
