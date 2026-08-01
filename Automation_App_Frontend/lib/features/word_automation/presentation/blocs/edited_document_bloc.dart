import 'dart:async';
import 'dart:developer' as developer;

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
  }

  Future<void> _onEditDocumentEvent(EditDocumentEvent event,
      Emitter<EditedDocumentState> emit,) async {
    emit(EditedDocumentLoading());

    if (event.path.isEmpty) {
      emit(const EditedDocumentError('Keine Vorlage geöffnet'));
      return;
    }

    final stopwatch = Stopwatch()
      ..start();
    final result = await fillOutTemplate(
      FillOutTemplateParams(
        path: event.path,
        data: event.data,
        damageListing: event.damageListing,
        vorsteuerabzugsberechtigt: event.vorsteuerabzugsberechtigt,
        outputFileName: event.outputFileName,
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
          ),
        );
    }
  }
}
