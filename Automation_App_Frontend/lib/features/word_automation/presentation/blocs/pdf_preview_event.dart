part of 'pdf_preview_bloc.dart';

sealed class PdfPreviewEvent extends Equatable {
  const PdfPreviewEvent();

  @override
  List<Object> get props => [];
}

final class LoadPdfPreviewEvent extends PdfPreviewEvent {
  final String docxFilePath;

  const LoadPdfPreviewEvent(this.docxFilePath);

  @override
  List<Object> get props => [docxFilePath];
}
