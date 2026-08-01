import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';

/// Zeigt den Zustand eines [PdfPreviewBloc] an: Hinweis, Spinner,
/// originalgetreues PDF (pdfrx) oder Fehlermeldung.
class PdfPreviewView extends StatelessWidget {
  final PdfPreviewBloc bloc;
  final String emptyHint;

  const PdfPreviewView({
    super.key,
    required this.bloc,
    this.emptyHint = 'Keine Vorschau vorhanden',
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PdfPreviewBloc, PdfPreviewState>(
      bloc: bloc,
      builder: (context, state) {
        return switch (state) {
          PdfPreviewInitial() => Center(child: Text(emptyHint)),
          PdfPreviewLoading() => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('PDF-Vorschau wird erstellt …'),
              ],
            ),
          ),
          PdfPreviewLoaded() => ColoredBox(
            color: Colors.grey.shade300,
            child: PdfViewer.data(
              state.pdfBytes,
              sourceName: state.sourceName,
              params: const PdfViewerParams(
                margin: 16,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          PdfPreviewError() => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.amber, size: 80),
                const SizedBox(height: 16),
                Text(state.message, textAlign: TextAlign.center),
              ],
            ),
          ),
        };
      },
    );
  }
}
