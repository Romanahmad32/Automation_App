import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Ein PDF als Seiten auf grauem Grund — die originalgetreue Vorschau eines
/// Word-Dokuments, so wie es gedruckt würde (Word-Assistent, Vollmacht).
///
/// [quelle] muss je Inhalt eindeutig sein: pdfrx erkennt ein Dokument an
/// diesem Namen und zeigte bei gleichem Namen die alte Seite weiter, auch
/// wenn die Bytes neu sind.
class PdfDokumentAnsicht extends StatelessWidget {
  final Uint8List pdf;
  final String quelle;

  const PdfDokumentAnsicht({
    super.key,
    required this.pdf,
    required this.quelle,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: PdfViewer.data(
        pdf,
        sourceName: quelle,
        params: const PdfViewerParams(
          margin: 16,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
