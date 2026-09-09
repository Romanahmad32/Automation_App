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
    on<DokumentAusVorgangEvent>(_onDokumentAusVorgangEvent);
  }

  /// Holt das am Vorgang vermerkte Schreiben zurück in den Wizard (§3), damit
  /// Begutachten, Ablegen, Versand und Abschluss auch nach einem Neustart
  /// erreichbar sind, ohne es neu zu erzeugen.
  ///
  /// **Was in dieser Sitzung erzeugt wurde, hat Vorrang.** Sonst nähme ein
  /// Vorgangswechsel dem Anwalt das Dokument weg, das er gerade vor sich hat —
  /// und genau das ist ein gebauter Weg: Ein ohne Vorgang erzeugtes Schreiben
  /// wird im Speicherschritt nachträglich einem Vorgang zugeordnet (§4.6).
  /// Abgeräumt wird deshalb nur ein zuvor wiederhergestellter Stand.
  void _onDokumentAusVorgangEvent(
    DokumentAusVorgangEvent event,
    Emitter<EditedDocumentState> emit,
  ) {
    final aktuell = state;
    if (aktuell is EditedDocumentLoaded && !aktuell.wiederhergestellt) return;

    final pfad = event.pfad?.trim() ?? '';
    // Ein Pfad, hinter dem nichts liegt (Datei verschoben, Arbeitsordner nach
    // dem Abschluss geräumt), ist so gut wie keiner — dann bleibt der Schritt
    // gesperrt, statt ins Leere zu führen.
    if (pfad.isEmpty || !File(pfad).existsSync()) {
      if (aktuell is EditedDocumentLoaded) emit(EditedDocumentInitial());
      return;
    }
    emit(
      EditedDocumentLoaded(
        pfad,
        erzeugtAm: _aenderungszeit(pfad),
        wiederhergestellt: true,
      ),
    );
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
        inAkteAbgelegt: true,
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
