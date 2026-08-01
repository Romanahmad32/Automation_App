import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eingabepanel für den manuellen Weg: die per E-Mail eingegangene
/// Zentralruf-Antwort einfügen oder als Datei (.txt/.eml) laden und auswerten
/// lassen. Das Ergebnis liefert der [ZentralrufReplyBloc] (aus dem Kontext) als
/// Zustand, den die umgebende Ansicht im editierbaren Formular darstellt.
class ManualReplyInput extends StatefulWidget {
  const ManualReplyInput({super.key});

  @override
  State<ManualReplyInput> createState() => _ManualReplyInputState();
}

class _ManualReplyInputState extends State<ManualReplyInput> {
  final _emailTextController = TextEditingController();

  /// Geladene .eml-Datei (Base64): wird unverändert ans Backend gegeben,
  /// das die MIME-Kodierung (Quoted-Printable, Base64, HTML) auflöst.
  String? _emlBase64;
  String? _emlFileName;

  @override
  void dispose() {
    _emailTextController.dispose();
    super.dispose();
  }

  Future<void> _loadFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Zentralruf-Antwort laden',
      type: FileType.custom,
      allowedExtensions: ['txt', 'eml'],
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;

    final bytes = await File(path).readAsBytes();
    if (path.toLowerCase().endsWith('.eml')) {
      setState(() {
        _emlBase64 = base64Encode(bytes);
        _emlFileName = file.name;
        _emailTextController.clear();
      });
      return;
    }

    // .txt: UTF-8 zuerst, Windows-Dateien sind aber oft Latin-1/ANSI.
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = latin1.decode(bytes);
    }
    setState(() {
      _emlBase64 = null;
      _emlFileName = null;
      _emailTextController.text = text;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text case final text? when text.trim().isNotEmpty) {
      setState(() {
        _emlBase64 = null;
        _emlFileName = null;
        _emailTextController.text = text;
      });
    }
  }

  void _extract() {
    final ZentralrufReplyInput input;
    if (_emlBase64 case final eml?) {
      input = ZentralrufReplyInput.emlBase64(eml);
    } else {
      final text = _emailTextController.text;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bitte zuerst den E-Mail-Text einfügen oder eine Datei laden.',
            ),
          ),
        );
        return;
      }
      input = ZentralrufReplyInput.text(text);
    }
    context.read<ZentralrufReplyBloc>().add(ParseZentralrufReplyEvent(input));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ZentralrufReplyBloc>().state;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Antwortmail des Zentralrufs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Fügen Sie den vollständigen Text der Antwortmail ein oder laden Sie '
            'sie als Datei (.txt oder .eml). Die App extrahiert daraus die Daten '
            'der gegnerischen Versicherung.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_emlFileName case final fileName?) ...[
            InputChip(
              avatar: const Icon(Icons.mail_outline),
              label: Text(fileName),
              onDeleted: () => setState(() {
                _emlBase64 = null;
                _emlFileName = null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: TextField(
              controller: _emailTextController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) {
                // Manuelle Eingabe ersetzt eine geladene .eml-Datei.
                if (_emlBase64 != null) {
                  setState(() {
                    _emlBase64 = null;
                    _emlFileName = null;
                  });
                }
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _emlFileName == null
                    ? 'E-Mail-Text hier einfügen …'
                    : 'Die geladene .eml-Datei wird ausgewertet.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _loadFromFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Aus Datei laden'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste),
                label: const Text('Aus Zwischenablage'),
              ),
              const Spacer(),
              CustomRectangularButton(
                label: state is ZentralrufReplyLoading
                    ? const Text('Wird ausgewertet …')
                    : const Text('Daten extrahieren'),
                onPressed: state is ZentralrufReplyLoading ? null : _extract,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
