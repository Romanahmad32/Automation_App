import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';

part 'document_event.dart';

part 'document_state.dart';

@injectable
class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  DocumentBloc() : super(DocumentInitial()) {
    on<SelectDocumentEvent>(_onSelectDocumentEvent);
    on<SetDocumentPathEvent>(
          (event, emit) => emit(DocumentLoaded(path: event.path)),
    );
  }

  Future<void> _onSelectDocumentEvent(SelectDocumentEvent event,
      Emitter<DocumentState> emit,) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    // Abbruch des Dialogs (result == null) oder fehlender Pfad ist kein Fehler:
    // einfach den bisherigen Zustand beibehalten, statt abzustürzen.
    if (result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.first.path;
    if (path == null) {
      return;
    }
    emit(DocumentLoaded(path: path));
  }
}
