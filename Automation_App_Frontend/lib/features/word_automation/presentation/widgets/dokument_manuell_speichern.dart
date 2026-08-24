import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/utils/dokument_export.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_format_auswahl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Sekundärer Weg: das Dokument an einen frei wählbaren Ort speichern — als
/// Word-Datei, als PDF oder beides.
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
  AblageFormat _format = AblageFormat.word;
  List<String> _gespeichert = const [];
  String? _fehler;
  bool _laeuft = false;

  Future<void> _speichern() async {
    final ziel = await _zielWaehlen();
    if (ziel == null || !mounted) return;

    setState(() {
      _laeuft = true;
      _fehler = null;
      _gespeichert = const [];
    });
    final ergebnis = await speichereFassungen(
      wordPfad: widget.outputPath,
      format: _format,
      zielOrdner: ziel.ordner,
      basisname: ziel.basisname,
    );
    if (!mounted) return;
    setState(() {
      _laeuft = false;
      _gespeichert = ergebnis.gespeichert;
      _fehler = ergebnis.fehler;
    });
  }

  /// Bei einer einzelnen Fassung wählt der Anwalt Ordner **und** Dateinamen,
  /// bei beiden nur den Ordner: zwei Speichern-Dialoge hintereinander wären
  /// eine Zumutung, und die Namen gehören ohnehin zusammen.
  Future<({String ordner, String basisname})?> _zielWaehlen() async {
    final vorschlag = dateibasisname(widget.outputPath);

    if (_format == AblageFormat.beide) {
      final ordner = await FilePicker.getDirectoryPath(
        dialogTitle: 'Ordner für Word-Datei und PDF wählen',
      );
      return ordner == null ? null : (ordner: ordner, basisname: vorschlag);
    }

    final endung = _format.mitPdf ? 'pdf' : 'docx';
    final pfad = await FilePicker.saveFile(
      dialogTitle: 'Dokument speichern',
      fileName: '$vorschlag.$endung',
      type: FileType.custom,
      allowedExtensions: [endung],
    );
    return pfad == null
        ? null
        : (ordner: ordnerVon(pfad), basisname: dateibasisname(pfad));
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
        AblageFormatAuswahl(
          titel: 'Was gespeichert wird',
          format: _format,
          onChanged: (format) => setState(() => _format = format),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _laeuft ? null : _speichern,
          icon: _laeuft
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open),
          label: Text(
            _format == AblageFormat.beide
                ? 'Ordner wählen & beide speichern'
                : 'Speicherort wählen & speichern',
          ),
        ),
        if (_gespeichert.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Gespeichert unter:\n${_gespeichert.join('\n')}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (_fehler != null) ...[
          const SizedBox(height: 8),
          Text(
            _fehler!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
