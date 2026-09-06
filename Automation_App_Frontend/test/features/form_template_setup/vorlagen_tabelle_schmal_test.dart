import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/delete_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Überlaufwächter der Vorlagen-Übersicht (Issue #57 an der Gestalt von
/// #104 Stufe 4): Die Zeile trägt seit Stufe 4 eine Spalte mehr (das
/// Kennzeichen) und eine Zeilenaktion mehr (Duplizieren). Beides drückt genau
/// dort, wo es bei angehobener Schrift ohnehin eng ist.
///
/// Geprüft wird dasselbe wie bei `felder_karte_schmal_test.dart`: **kein
/// Überlauf** bei 700 px und größter Schriftstufe, und bei 1600 px steht jede
/// Kopfaufschrift ungekürzt da.

class FesteVorlagen implements UseCase<List<FormTemplate>, NoParams> {
  @override
  Future<Either<Failure, List<FormTemplate>>> call(NoParams params) async =>
      Right(const []);
}

class StillesLoeschen implements UseCase<void, DeleteFormTemplateParams> {
  @override
  Future<Either<Failure, void>> call(DeleteFormTemplateParams params) async =>
      Right(null);
}

/// Die Kopfaufschriften der Tabelle — hier als Liste, weil sie im Kopf-Widget
/// nur an einer Stelle stehen und der Wächter sie sonst dreimal nachhielte.
const aufschriften = ['Vorlage', 'Dateien', 'Stand', 'Felder', 'Aktionen'];

void main() {
  List<FieldData> felder(int anzahl) => [
    for (var i = 0; i < anzahl; i++)
      FieldData(
        order: i,
        label: 'Feldname Nummer $i',
        required: i.isEven,
        inputType: InputType.text,
      ),
  ];

  /// Drei Zeilen, die zusammen jeden Fall des Kennzeichens zeigen: keine
  /// Angabe (Bestandsvorlage), vollständig, unvollständig mit zweistelliger
  /// Zahl — der längste Text, den die neue Spalte tragen kann.
  final vorlagen = [
    FormTemplate(
      id: 1,
      templateName: 'Anspruchsschreiben Haftpflicht ohne Auflistung',
      fields: felder(12),
      wordFilePathOhneAuflistung: 'ohne.docx',
    ),
    FormTemplate(
      id: 2,
      templateName: 'Anspruchsschreiben mit Schadensaufstellung',
      fields: felder(18),
      wordFilePathOhneAuflistung: 'ohne.docx',
      wordFilePathMitAuflistung: 'mit.docx',
      stand: const GespeicherterStand(
        vollstaendig: true,
        offen: 0,
        warnungen: false,
      ),
    ),
    FormTemplate(
      id: 3,
      templateName: 'Mahnung',
      fields: felder(1),
      stand: const GespeicherterStand(
        vollstaendig: false,
        offen: 14,
        warnungen: true,
      ),
    ),
  ];

  Future<void> pumpeTabelle(
    WidgetTester tester, {
    required Size fenstergroesse,
    required Schriftstufe schriftstufe,
  }) async {
    tester.view.physicalSize = fenstergroesse;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final uebersicht = FormTemplateOverviewBloc(
      FesteVorlagen(),
      StillesLoeschen(),
    );
    addTearDown(uebersicht.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: uebersicht,
            // Derselbe Rand wie in `FormTemplateManagementPage`: Der Wächter
            // soll die Breite messen, die die Tabelle dort wirklich bekommt.
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FormTemplateTable(templates: vorlagen),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'läuft bei größter Schrift und schmalem Fenster (700 px) nicht über',
    (tester) async {
      await pumpeTabelle(
        tester,
        fenstergroesse: const Size(700, 900),
        schriftstufe: Schriftstufe.amGroessten,
      );

      expect(tester.takeException(), isNull);
      // Und zeigt dabei wirklich, worum es geht: das Kennzeichen je Zeile und
      // die Duplizier-Aktion.
      expect(find.text('Unvollständig · 14 offen'), findsOneWidget);
      expect(find.text('Vollständig'), findsOneWidget);
      expect(find.text('Noch nicht geprüft'), findsOneWidget);
      expect(find.byTooltip('Duplizieren'), findsNWidgets(3));
    },
  );

  testWidgets(
    'bleibt bei normaler Schrift und breitem Fenster (1600 px) unauffällig',
    (tester) async {
      await pumpeTabelle(
        tester,
        fenstergroesse: const Size(1600, 900),
        schriftstufe: Schriftstufe.normal,
      );

      expect(tester.takeException(), isNull);
      for (final text in aufschriften) {
        final absatz = tester.renderObject<RenderParagraph>(find.text(text));
        expect(absatz.didExceedMaxLines, isFalse, reason: text);
      }
    },
  );
}
