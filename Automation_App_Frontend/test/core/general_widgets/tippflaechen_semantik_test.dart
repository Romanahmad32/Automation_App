import 'package:automation_app/core/general_widgets/drawer/side_bar_item.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_vollmacht_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/settings/presentation/widgets/tabellenkopf_farbe_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Eigene Tippflächen (`InkWell` ohne Material-Knopf) melden sich als Knopf —
/// für Screenreader (Abnahmebefund B1) und damit als bedienbares Element für
/// Marionette. Ohne `Semantics` meldete der `InkWell` nur eine Tipp-Aktion.
void main() {
  Future<SemanticsHandle> baue(WidgetTester tester, Widget kind) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: kind)));
    return handle;
  }

  SidebarItem reiter({required bool ausgeklappt}) => SidebarItem(
    icon: const Icon(Icons.home_outlined),
    selectedIcon: const Icon(Icons.home),
    label: 'Übersicht',
    isSelected: false,
    isExtended: ausgeklappt,
    animationDuration: Duration.zero,
    collapsedWidth: 72,
    onTap: () {},
  );

  testWidgets('der Reiter der Seitenleiste ist ein Knopf mit '
      'seinem Namen', (tester) async {
    final handle = await baue(tester, reiter(ausgeklappt: false));

    final knoten = tester.getSemantics(find.byType(InkWell));

    expect(
      knoten,
      matchesSemantics(
        label: 'Übersicht',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('der ausgeklappte Reiter liest seinen Namen nicht doppelt', (
    tester,
  ) async {
    final handle = await baue(tester, reiter(ausgeklappt: true));

    final knoten = tester.getSemantics(find.byType(InkWell));

    expect(knoten.label, 'Übersicht');
    expect(knoten.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('der Vollmacht-Hinweis ist ein Knopf mit seinem Text', (
    tester,
  ) async {
    final handle = await baue(
      tester,
      const DashboardVollmachtHinweis(anzahl: 2),
    );

    final knoten = tester.getSemantics(find.byType(InkWell));

    expect(
      knoten,
      matchesSemantics(
        label: '2 offene Vorgänge ohne gedruckte Vollmacht',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('ein Farbfeld ohne Text im Kind heißt wie seine Farbe', (
    tester,
  ) async {
    final form = FormGroup({
      'tabellenkopfFarbeHex': FormControl<String>(value: 'D9D9D9'),
    });
    final handle = await baue(
      tester,
      ReactiveForm(formGroup: form, child: const TabellenkopfFarbeField()),
    );

    final knoten = tester.getSemantics(find.byType(InkWell).at(1));

    // Genau einmal: Der Tooltip trägt den Namen, ein Label darf ihn nicht
    // ein zweites Mal beisteuern.
    expect(knoten.tooltip, 'Blau');
    expect(knoten.label, isNot(contains('Blau')));
    expect(knoten.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('der Umschalter „neutral anreden“ ist ein Knoten mit '
      'Checkbox-Zustand, Tipp-Aktion und Beschriftung', (tester) async {
    final handle = await baue(
      tester,
      AnredeNeutralSchalter(neutral: true, aktiv: true, onUmschalten: (_) {}),
    );

    final knoten = tester.getSemantics(find.byType(InkWell));

    expect(
      knoten,
      matchesSemantics(
        label: 'Neutral anreden („Damen und Herren")',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
