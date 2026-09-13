import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/dokument_export.dart';
import 'package:automation_app/features/word_automation/presentation/utils/speicher_vermerk.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_format_auswahl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    // Gespeichert ist gespeichert (§4.9, #133): Auch die frei gewählte Ablage
    // belegt die Nummer des Schreibens, sonst fragte die App beim nächsten Mal
    // nicht nach — und das zweite Schreiben überschriebe hier das erste. Was
    // sie *nicht* tut: Status, Dokumentpfad und Aktenordner anfassen. Die Datei
    // liegt nicht in der Akte; sie zum Dokument des Vorgangs zu erklären,
    // widerspräche §4.6.
    if (ergebnis.gespeichert.isEmpty) return;
    _vermerke();
  }

  /// Der Vermerk am Vorgang — nur, wenn überhaupt einer gewählt ist. Der
  /// frischeste Stand kommt aus dem [VorgangCubit]: Die Kopie im Wizard kann
  /// seit dem Erzeugen veraltet sein (zurückgeflossene Feldwerte).
  void _vermerke() {
    final wizard = context.read<WizardCubit>();
    final gewaehlt = wizard.state.selectedVorgang;
    if (gewaehlt == null) return;
    final vorgaenge = getIt<VorgangCubit>();
    vermerkeGespeichertesSchreiben(
      vorgaenge: vorgaenge,
      wizard: wizard,
      vorgang: vorgaenge.findeZuReferenz(gewaehlt.referenz) ?? gewaehlt,
    );
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
