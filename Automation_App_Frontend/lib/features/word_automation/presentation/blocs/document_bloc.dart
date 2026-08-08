import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';

part 'document_event.dart';

part 'document_state.dart';

@injectable
class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  DocumentBloc(this._vorlagenUebersicht) : super(DocumentInitial()) {
    on<SelectDocumentEvent>(_onSelectDocumentEvent);
    on<SetDocumentPathEvent>(
      (event, emit) => emit(DocumentLoaded(path: event.path)),
    );
  }

  final UseCase<VorlagenUebersicht, NoParams> _vorlagenUebersicht;

  Future<void> _onSelectDocumentEvent(
    SelectDocumentEvent event,
    Emitter<DocumentState> emit,
  ) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      // Der Dialog öffnet im Vorlagenordner. Ohne das beginnt „Durchsuchen"
      // irgendwo im Dateisystem, und der Anwalt müsste den Pfad nach %APPDATA%
      // kennen, um an seine eigenen Vorlagen zu kommen.
      initialDirectory: await _vorlagenOrdner(),
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

  /// Der Vorlagenordner, oder `null`, wenn der Dienst ihn nicht nennen kann —
  /// dann öffnet der Dialog im Standardverzeichnis. Eine Auswahl soll nicht
  /// daran scheitern, dass ein Startordner nicht ermittelbar war.
  Future<String?> _vorlagenOrdner() async {
    final ergebnis = await _vorlagenUebersicht(const NoParams());
    return switch (ergebnis) {
      Right(value: final uebersicht) => uebersicht.verzeichnis,
      Left() => null,
    };
  }
}
