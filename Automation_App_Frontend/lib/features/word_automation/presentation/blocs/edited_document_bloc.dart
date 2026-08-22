import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'edited_document_event.dart';

part 'edited_document_state.dart';

@injectable
class EditedDocumentBloc
    extends Bloc<EditedDocumentEvent, EditedDocumentState> {
  final UseCase<GeneratedDocument, FillOutTemplateParams> fillOutTemplate;

  EditedDocumentBloc(this.fillOutTemplate) : super(EditedDocumentInitial()) {
    on<EditDocumentEvent>(_onEditDocumentEvent);
    on<DokumentAbgelegtEvent>(_onDokumentAbgelegtEvent);
  }

  /// Übernimmt den Ablageort in der Akte als neuen Arbeitspfad. Die Warnungen
  /// der Erzeugung bleiben stehen — dasselbe Dokument, nur an seinem Platz.
  void _onDokumentAbgelegtEvent(
    DokumentAbgelegtEvent event,
    Emitter<EditedDocumentState> emit,
  ) {
    final aktuell = state;
    if (aktuell is! EditedDocumentLoaded) return;
    emit(
      EditedDocumentLoaded(
        event.zielpfad,
        warnings: aktuell.warnings,
        erzeugtAm: _aenderungszeit(event.zielpfad),
      ),
    );
  }

  /// Änderungszeit der Datei, oder null, wenn sie nicht zu lesen ist (im Test
  /// zeigt der Pfad ins Nichts). Null heisst nur: kein Vergleich möglich.
  DateTime? _aenderungszeit(String pfad) {
    try {
      final datei = File(pfad);
      return datei.existsSync() ? datei.lastModifiedSync() : null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _onEditDocumentEvent(
    EditDocumentEvent event,
    Emitter<EditedDocumentState> emit,
  ) async {
    emit(EditedDocumentLoading());

    if (event.path.isEmpty) {
      emit(const EditedDocumentError('Keine Vorlage geöffnet'));
      return;
    }

    final stopwatch = Stopwatch()..start();
    final result = await fillOutTemplate(
      FillOutTemplateParams(
        path: event.path,
        data: event.data,
        damageListing: event.damageListing,
        vorsteuerabzugsberechtigt: event.vorsteuerabzugsberechtigt,
        outputFileName: event.outputFileName,
        vorgangSchluessel: event.vorgangSchluessel,
      ),
    );
    stopwatch.stop();
    developer.log(
      'Gesamte Anfrage (Absenden → Antwort, = Spinner-Dauer): '
      '${stopwatch.elapsedMilliseconds} ms',
      name: 'PERF',
    );

    switch (result) {
      case Left(value: final failure):
        emit(EditedDocumentError(failure.message));
      case Right(value: final document):
        emit(
          EditedDocumentLoaded(
            document.outputFilePath,
            warnings: document.warnings,
            erzeugtAm: _aenderungszeit(document.outputFilePath),
          ),
        );
    }
  }
}
