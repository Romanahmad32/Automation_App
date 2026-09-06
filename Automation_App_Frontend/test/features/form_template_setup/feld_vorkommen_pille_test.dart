import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/auflistung_badge.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_bezeichnung_zelle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Das Kennzeichen an der Feldzeile ([FeldBezeichnungZelle]) zeigt seit #104
/// wieder alle vier Fälle aus `FeldVorkommen` — *beide · nur HGn · nur
/// Auflistung · in keiner Datei* —, auf ausdrücklichen Wunsch des Anwalts:
/// Die beiden Word-Dateien sind gleichwertig, und er will an jeder Zeile
/// sehen, welches Feld welche Datei bedient.
///
/// Die drei Auskunftsfälle bleiben ruhig (neutraler Rand, kein Klickweg); nur
/// „in keiner Datei" ist ein Befund, der etwas kostet, und zugleich der Weg
/// zur Zuordnung (#36) — das prüft dieser Test weiterhin.
class FestePlatzhalterJeSlot
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async {
    if (params.wordFilePath == 'ohne.docx') {
      return Right(['Beide', 'NurHgn']);
    }
    return Right(['Beide', 'NurAuflistung']);
  }
}

/// Vier Felder, deren Namen absichtlich je einen der vier Fälle treffen:
/// „Beide" steht in beiden Dateien, „NurHgn" nur in der Datei ohne
/// Auflistung, „NurAuflistung" nur in der Datei mit Auflistung, „Vertippt"
/// in keiner der beiden.
Future<void> pumpeZeilen(
  WidgetTester tester, {
  void Function(String feld)? onZuordnen,
  double? zellenbreite,
  Schriftstufe schriftstufe = Schriftstufe.normal,
}) async {
  final bloc = TemplatePlaceholdersBloc(FestePlatzhalterJeSlot())
    ..add(
      const LoadTemplatePlaceholders(
        'ohne.docx',
        TemplateFileSlot.ohneAuflistung,
      ),
    )
    ..add(
      const LoadTemplatePlaceholders(
        'mit.docx',
        TemplateFileSlot.mitAuflistung,
      ),
    );
  addTearDown(bloc.close);

  final formGroup = FormGroup({
    'field_0': FormControl<String>(value: 'Beide'),
    'field_1': FormControl<String>(value: 'NurHgn'),
    'field_2': FormControl<String>(value: 'NurAuflistung'),
    'field_3': FormControl<String>(value: 'Vertippt'),
  });

  Widget zelle(String feld) {
    final inhalt = FeldBezeichnungZelle(
      formControlName: feld,
      onZuordnen: onZuordnen == null ? null : () => onZuordnen(feld),
    );
    return zellenbreite == null
        ? inhalt
        : SizedBox(width: zellenbreite, child: inhalt);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: MaterialTheme(
        ThemeData.light().textTheme,
        schriftstufe: schriftstufe,
      ).light(),
      home: Scaffold(
        body: BlocProvider.value(
          value: bloc,
          child: ReactiveForm(
            formGroup: formGroup,
            child: Column(
              children: [
                for (final feld in ['field_0', 'field_1', 'field_2', 'field_3'])
                  zelle(feld),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // Einmal für die Antwort des Anwendungsfalls, einmal für den Neuaufbau.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('alle vier Fälle erscheinen mit ihrem Text', (tester) async {
    await pumpeZeilen(tester);

    expect(find.text('beide'), findsOneWidget);
    expect(find.text('nur HGn'), findsOneWidget);
    expect(find.text('nur Auflistung'), findsOneWidget);
    expect(find.text('in keiner Datei'), findsOneWidget);
  });

  testWidgets('nur „in keiner Datei" reagiert auf Klick und zeigt Icons.link', (
    tester,
  ) async {
    final geklickt = <String>[];
    await pumpeZeilen(tester, onZuordnen: geklickt.add);

    // Jeder Fall trägt sein eigenes Symbol — Icons.link steht damit für
    // genau eine Zeile, nicht für alle vier.
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);

    await tester.tap(find.text('in keiner Datei'));
    expect(geklickt, ['field_3']);

    // Die drei Auskunfts-Pillen reagieren nicht auf einen Klick.
    await tester.tap(find.text('beide'));
    await tester.tap(find.text('nur HGn'));
    await tester.tap(find.text('nur Auflistung'));
    expect(geklickt, ['field_3']);
  });

  testWidgets('die neutralen Pillen tragen nicht die Fehlerfarbe', (
    tester,
  ) async {
    await pumpeZeilen(tester);
    final theme = MaterialTheme(
      ThemeData.light().textTheme,
      schriftstufe: Schriftstufe.normal,
    ).light();

    final badges = tester
        .widgetList<AuflistungBadge>(find.byType(AuflistungBadge))
        .toList();
    expect(badges, hasLength(4));
    expect(badges[0].accent, theme.colorScheme.onSurfaceVariant); // beide
    expect(badges[1].accent, theme.colorScheme.onSurfaceVariant); // nur HGn
    expect(
      badges[2].accent,
      theme.colorScheme.onSurfaceVariant,
    ); // nur Auflistung
    expect(badges[3].accent, theme.colorScheme.error); // in keiner Datei
  });

  testWidgets('läuft bei schmaler Zelle (220 px) und größter Schrift nicht '
      'über', (tester) async {
    await pumpeZeilen(
      tester,
      zellenbreite: 220,
      schriftstufe: Schriftstufe.amGroessten,
    );

    expect(tester.takeException(), isNull);
  });
}
