import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_badge.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_pille.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(['Kennzeichen']);
}

/// Das Kennzeichen an der Feldzeile ist bei „in keiner Datei" zugleich der Weg
/// zur Reparatur (#36) — ein Feld, dessen Wert beim Erzeugen verworfen wird,
/// soll sich an Ort und Stelle zuordnen lassen.
///
/// Die drei anderen Fälle (*beide · nur HGn · nur Auflistung*) zeigt es seit
/// #104 **nicht** mehr, und dieser Test hält das fest. Sie waren reine
/// Auskunft und standen an jeder Zeile: achtzehn Kennzeichen, die sagen, dass
/// alles in Ordnung ist, verstecken das eine, das es nicht ist. Der frühere
/// Test „die reine Auskunft klickt nicht ins Leere" ist damit
/// gegenstandslos — an seine Stelle tritt die Gegenprobe, dass die drei gar
/// nicht mehr erscheinen. Der Befund selbst und sein Klickweg sind
/// unverändert geprüft.
void main() {
  /// Zwei Felder an einer Vorlage, deren HGn-Datei nur `{{Kennzeichen}}`
  /// kennt: „Kennzeichen" kommt dort an, „Zeichen" nirgends.
  Future<void> zeigeBadges(
    WidgetTester tester, {
    void Function(String feld)? onZuordnen,
  }) async {
    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter())
      ..add(
        const LoadTemplatePlaceholders(
          'egal.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    addTearDown(bloc.close);
    final formGroup = FormGroup({
      'field_0': FormControl<String>(value: 'Kennzeichen'),
      'field_1': FormControl<String>(value: 'Zeichen'),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formGroup,
              child: Column(
                children: [
                  for (final feld in ['field_0', 'field_1'])
                    FeldVorkommenBadge(
                      formControlName: feld,
                      onZuordnen: onZuordnen == null
                          ? null
                          : () => onZuordnen(feld),
                    ),
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

  testWidgets('„in keiner Datei" führt zur Zuordnung', (tester) async {
    final geklickt = <String>[];
    await zeigeBadges(tester, onZuordnen: geklickt.add);

    expect(find.text('in keiner Datei'), findsOne);
    await tester.tap(find.text('in keiner Datei'));

    expect(geklickt, ['field_1']);
  });

  testWidgets('die reine Auskunft steht nicht mehr an der Zeile', (
    tester,
  ) async {
    await zeigeBadges(tester, onZuordnen: (_) {});

    // „Kennzeichen" steht in der HGn-Datei — daran gibt es nichts zu ordnen
    // und nichts zu melden. Genau ein Kennzeichen bleibt übrig, das der
    // Warnung.
    expect(find.text('nur HGn'), findsNothing);
    expect(find.text('beide'), findsNothing);
    expect(find.text('nur Auflistung'), findsNothing);
    expect(find.byType(FeldVorkommenPille), findsOne);
  });

  testWidgets('ohne Rückmeldung bleibt das Kennzeichen stumm, statt einen Weg '
      'zu zeigen, den es nicht gibt', (tester) async {
    await zeigeBadges(tester);

    expect(find.text('in keiner Datei'), findsOne);
    expect(find.byIcon(Icons.link), findsNothing);
  });
}
