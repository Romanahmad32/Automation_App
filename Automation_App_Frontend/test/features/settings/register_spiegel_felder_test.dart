import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/widgets/register_spiegel_felder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Schalter und Auswahl der Register-Datei hängen über `reactive_forms` am
/// Formular (Issue #185: nicht mehr über die alten Reactive-Widgets).
void main() {
  late FormGroup form;

  setUp(() {
    form = FormGroup({
      'registerDateiname': FormControl<String>(value: 'Register'),
      'registerNachAbschlussSchreiben': FormControl<bool>(value: false),
      'registerExportFilter': FormControl<String>(
        value: KanzleiSettings.registerFilterAlle,
      ),
    });
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReactiveForm(
              formGroup: form,
              child: const RegisterSpiegelFelder(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dropdown() => find.byType(DropdownButtonFormField<String>);

  testWidgets('Wert aus dem Control erscheint im Schalter und im Dropdown', (
    tester,
  ) async {
    await zeige(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Alle Vorgänge'), findsOneWidget);

    form.control('registerNachAbschlussSchreiben').updateValue(true);
    form
        .control('registerExportFilter')
        .updateValue(KanzleiSettings.registerFilterAbgeschlossen);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('Nur abgeschlossene Vorgänge'), findsOneWidget);
  });

  testWidgets('Bedienung schreibt zurück ins Control', (tester) async {
    await zeige(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(form.control('registerNachAbschlussSchreiben').value, isTrue);

    await tester.tap(dropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nur abgeschlossene Vorgänge').last);
    await tester.pumpAndSettle();
    expect(
      form.control('registerExportFilter').value,
      KanzleiSettings.registerFilterAbgeschlossen,
    );
  });

  testWidgets('ein gesperrtes Control sperrt Schalter und Dropdown', (
    tester,
  ) async {
    form.control('registerNachAbschlussSchreiben').markAsDisabled();
    form.control('registerExportFilter').markAsDisabled();
    await zeige(tester);

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButtonFormField<String>>(dropdown()).onChanged,
      isNull,
    );
  });

  for (final unbekannt in ['', 'gibtsnicht']) {
    testWidgets('unbekannter Dropdown-Wert "$unbekannt" zeigt keine Auswahl', (
      tester,
    ) async {
      form.control('registerExportFilter').updateValue(unbekannt);
      await zeige(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Alle Vorgänge'), findsNothing);
      expect(find.text('Nur abgeschlossene Vorgänge'), findsNothing);
    });
  }
}
