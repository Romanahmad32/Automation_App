import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Sekundärer Weg: das Dokument an einen frei wählbaren Ort kopieren.
///
/// Quelle ist das, woran der Wizard gerade arbeitet: vor der Ablage die
/// Arbeitskopie, danach die Datei in der Akte. Eine dauerhafte Zweitfassung
/// im Arbeitsordner gibt es nicht — der wird nach der Ablage gelöscht.
class DokumentManuellSpeichern extends StatefulWidget {
  final String outputPath;

  const DokumentManuellSpeichern({super.key, required this.outputPath});

  @override
  State<DokumentManuellSpeichern> createState() =>
      _DokumentManuellSpeichernState();
}

class _DokumentManuellSpeichernState extends State<DokumentManuellSpeichern> {
  String? _savedPath;
  String? _saveError;

  Future<void> _saveDocument() async {
    final fileName = widget.outputPath.split(RegExp(r'[\\/]')).last;
    final targetPath = await FilePicker.saveFile(
      dialogTitle: 'Dokument speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (targetPath == null) return;

    try {
      await File(widget.outputPath).copy(targetPath);
      setState(() {
        _savedPath = targetPath;
        _saveError = null;
      });
    } on FileSystemException catch (e) {
      setState(() => _saveError = 'Speichern fehlgeschlagen: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'An anderen Ort speichern',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saveDocument,
          icon: const Icon(Icons.folder_open),
          label: Text(
            _savedPath == null
                ? 'Speicherort wählen & speichern'
                : 'Erneut speichern …',
          ),
        ),
        if (_savedPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Gespeichert unter:\n$_savedPath',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(
            _saveError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
