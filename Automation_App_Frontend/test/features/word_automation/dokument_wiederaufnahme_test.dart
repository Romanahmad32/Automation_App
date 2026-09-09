import 'dart:io';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/wiederaufnahme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein Schreiben gehört zum Vorgang, nicht zur Sitzung (§3).
///
/// Vorher kannte der Wizard nur, was er selbst gerade erzeugt hatte: Nach einem
/// Neustart waren „Dokument begutachten" und „Speichern & weiter" gesperrt, und
/// der Absprung „Versenden & abschließen" eines abgelegten Vorgangs landete in
/// „Es wurde noch kein Dokument erstellt". Versand (§4.7) und Abschluss (§4.8)
/// hängen aber genau an diesem Schritt — der einzige Weg dorthin wäre gewesen,
/// das Schreiben neu zu erzeugen, für einen Schritt, der die Auftragsnummer
/// hochzählt.
class _FakeFillOutTemplate
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) async => Right(
    GeneratedDocument(
      outputFilePath: r'C:\App\Generated\Arbeit\84-26 C03\Brief.docx',
      warnings: const ['Unbekannt'],
    ),
  );
}

void main() {
  late Directory ordner;
  late File schreiben;

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('wiederaufnahme');
    schreiben = File('${ordner.path}${Platform.pathSeparator}Brief.docx')
      ..writeAsStringSync('Anspruchsschreiben');
  });

  tearDown(() => ordner.deleteSync(recursive: true));

  Vorgang vorgang({
    required VorgangStatus status,
    String? dokumentPfad,
    String referenz = '84/26 C03_GG-XY 123',
  }) => Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 3),
    status: status,
    dokumentPfad: dokumentPfad,
  );

  group('EditedDocumentBloc', () {
    test('holt das am Vorgang vermerkte Schreiben zurück', () async {
      final bloc = EditedDocumentBloc(_FakeFillOutTemplate());

      bloc.add(DokumentAusVorgangEvent(schreiben.path));
      final state = await bloc.stream.first as EditedDocumentLoaded;

      expect(state.path, schreiben.path);
      // Die Marke trennt „aus dem Vorgang geholt" von „gerade erzeugt": Nur am
      // zweiten hängen Statuswechsel, Schreiben-Nummer (§4.9) und der Sprung
      // ins Begutachten.
      expect(state.wiederhergestellt, isTrue);
      expect(state.warnings, isEmpty);
    });

    test('ein Pfad, hinter dem nichts liegt, ist so gut wie keiner', () async {
      final bloc = EditedDocumentBloc(_FakeFillOutTemplate());

      bloc.add(DokumentAusVorgangEvent('${ordner.path}/geloescht.docx'));
      // Nach dem Abschluss räumt der Dienst den Arbeitsordner (§4.8) — der
      // Vorgang trägt den Pfad dann weiter, die Datei gibt es nicht mehr.
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<EditedDocumentInitial>());
    });

    test('was in dieser Sitzung erzeugt wurde, wird nicht verdrängt', () async {
      final bloc = EditedDocumentBloc(_FakeFillOutTemplate());
      bloc.add(
        const EditDocumentEvent(
          data: {'Name': 'Mustermann'},
          path: r'C:\Vorlagen\VORLAGE HGn.docx',
        ),
      );
      final erzeugt =
          await bloc.stream.firstWhere((s) => s is EditedDocumentLoaded)
              as EditedDocumentLoaded;

      // Ein ohne Vorgang erzeugtes Schreiben wird im Speicherschritt
      // nachträglich zugeordnet (§4.6). Würde die Zuordnung es durch den Stand
      // des Vorgangs ersetzen, nähme sie dem Anwalt das Dokument weg, das er
      // gerade vor sich hat — samt seiner Warnungen.
      bloc.add(DokumentAusVorgangEvent(schreiben.path));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, erzeugt);
      expect((bloc.state as EditedDocumentLoaded).warnings, ['Unbekannt']);
    });
  });

  group('wiederaufnahmeSchritt', () {
    test('führt dorthin, wo der Absprung es verspricht', () {
      // Dieselbe Zuordnung, die `VorgangNaechsterSchritt` auf den Knopf
      // schreibt: „Prüfen & ablegen" und „Versenden & abschließen".
      expect(
        wiederaufnahmeSchritt(
          vorgang(status: VorgangStatus.erstellt, dokumentPfad: schreiben.path),
        ),
        WizardStep.review,
      );
      expect(
        wiederaufnahmeSchritt(
          vorgang(status: VorgangStatus.abgelegt, dokumentPfad: schreiben.path),
        ),
        WizardStep.save,
      );
    });

    test('springt nicht ohne benutzbares Dokument', () {
      // Ein Sprung auf einen gesperrten Schritt wäre nur eine andere Sackgasse.
      expect(
        wiederaufnahmeSchritt(vorgang(status: VorgangStatus.erstellt)),
        isNull,
      );
      expect(
        wiederaufnahmeSchritt(
          vorgang(
            status: VorgangStatus.erstellt,
            dokumentPfad: '${ordner.path}/geloescht.docx',
          ),
        ),
        isNull,
      );
    });

    test('lässt Anfang und Ende des Lebenszyklus in Ruhe', () {
      // Vor dem ersten Schreiben beginnt die Arbeit beim Ausfüllen, und ein
      // abgeschlossener Vorgang hat keinen nächsten Schritt mehr.
      for (final status in [
        VorgangStatus.angefragt,
        VorgangStatus.beantwortet,
        VorgangStatus.versendet,
      ]) {
        expect(
          wiederaufnahmeSchritt(
            vorgang(status: status, dokumentPfad: schreiben.path),
          ),
          isNull,
          reason: 'Status $status darf keinen Sprung auslösen',
        );
      }
      expect(wiederaufnahmeSchritt(null), isNull);
    });
  });

  group('andererVorgang', () {
    test('unterscheidet den Wechsel vom neuen Stand desselben Vorgangs', () {
      final vorher = vorgang(status: VorgangStatus.beantwortet);
      // Der Rückfluss nach dem Erzeugen hebt die Auswahl auf denselben Vorgang
      // mit neuem Stand — das darf das frische Dokument nicht verwerfen.
      expect(
        andererVorgang(
          vorher,
          vorher.copyWith(
            status: VorgangStatus.erstellt,
            dokumentPfad: schreiben.path,
          ),
        ),
        isFalse,
      );
      expect(
        andererVorgang(
          vorher,
          vorgang(status: VorgangStatus.angefragt, referenz: '85/26 C03'),
        ),
        isTrue,
      );
      expect(andererVorgang(null, vorher), isTrue);
      expect(andererVorgang(null, null), isFalse);
    });
  });
}
