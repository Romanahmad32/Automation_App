part of 'pdf_preview_bloc.dart';

sealed class PdfPreviewState extends Equatable {
  const PdfPreviewState();

  @override
  List<Object> get props => [];
}

final class PdfPreviewInitial extends PdfPreviewState {}

final class PdfPreviewLoading extends PdfPreviewState {}

final class PdfPreviewLoaded extends PdfPreviewState {
  final Uint8List pdfBytes;

  /// Eindeutiger Name für den Viewer (Pfad + Ladezähler), damit pdfrx bei
  /// neuem Inhalt unter gleichem Pfad nicht den alten Stand anzeigt.
  final String sourceName;

  const PdfPreviewLoaded({required this.pdfBytes, required this.sourceName});

  @override
  List<Object> get props => [sourceName];
}

final class PdfPreviewError extends PdfPreviewState {
  final String message;

  const PdfPreviewError(this.message);

  @override
  List<Object> get props => [message];
}
