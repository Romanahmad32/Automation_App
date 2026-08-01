import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Zeigt die geladene Word-Datei bzw. bietet an, eine zu wählen, wenn der
/// aktive Slot noch keine (gültige) Verknüpfung hat.
class WordFileRow extends StatelessWidget {
  final String? loadedPath;

  const WordFileRow({super.key, this.loadedPath});

  @override
  Widget build(BuildContext context) {
    if (loadedPath == null) {
      return CustomRectangularButton(
        onPressed: () =>
            context.read<DocumentBloc>().add(const SelectDocumentEvent()),
        icon: const Icon(Icons.file_open),
        label: const Text('Word-Datei wählen'),
      );
    }

    return Row(
      children: [
        const Icon(Icons.description, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            loadedPath!.split(RegExp(r'[\\/]')).last,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () =>
              context.read<DocumentBloc>().add(const SelectDocumentEvent()),
          child: const Text('Andere Datei …'),
        ),
      ],
    );
  }
}
