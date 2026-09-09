import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/app_daten_ordner_feld.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_zustand_zeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/register_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/sicherungs_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/stammordner_field.dart';
import 'package:automation_app/features/settings/presentation/widgets/vorlagen_ordner_feld.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'kanzlei_settings_doubles.dart';

/// Die vereinfachte Einrichtung zeigt Sonderpfade erst auf Wunsch. Bestehende
/// und spät geladene Abweichungen müssen dennoch sofort erkennbar bleiben.
void main() {
  FormGroup formular({String vorlagenOrdner = ''}) => FormGroup({
    'appDatenOrdner': FormControl<String>(),
    'aktenStammordner': FormControl<String>(),
    'vorlagenOrdner': FormControl<String>(value: vorlagenOrdner),
    'registerAblageOrdner': FormControl<String>(),
    'sicherungsAblageOrdner': FormControl<String>(),
  });

  Future<void> zeige(WidgetTester tester, FormGroup form) async {
    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(KanzleiSettings.empty),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider.value(
              value: bloc,
              child: ReactiveForm(
                formGroup: form,
                child: const OrdnerSektion(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt die eine Ordnerwahl und den Akten-Stammordner offen', (
    tester,
  ) async {
    await zeige(tester, formular());

    expect(find.byType(AppDatenOrdnerFeld), findsOneWidget);
    expect(find.byType(StammordnerField), findsOneWidget);
    expect(find.text('Erweiterte Einstellungen'), findsOneWidget);

    expect(
      find.byType(VorlagenOrdnerFeld),
      findsNothing,
      reason:
          'Sichtbar ist im Normalfall nur der eine Ordner — sonst ist aus vier '
          'Wahlen nichts geworden.',
    );
    expect(find.byType(RegisterAblageFelder), findsNothing);
    expect(find.byType(SicherungsAblageFelder), findsNothing);
  });

  testWidgets(
    'nennt bestehende Sonderpfade geschlossen und bewahrt sie beim Öffnen',
    (tester) async {
      final form = formular(vorlagenOrdner: r'C:\Kanzlei\Vorlagen');
      await zeige(tester, form);
      expect(
        find.textContaining('Abweichende Ablage aktiv: Vorlagen'),
        findsOneWidget,
      );
      expect(find.byType(VorlagenOrdnerFeld), findsNothing);
      await tester.ensureVisible(find.text('Erweiterte Einstellungen'));
      await tester.tap(find.text('Erweiterte Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.byType(VorlagenOrdnerFeld), findsOneWidget);
      expect(find.byType(RegisterAblageFelder), findsOneWidget);
      expect(find.byType(SicherungsAblageFelder), findsOneWidget);
      expect(form.control('vorlagenOrdner').value, r'C:\Kanzlei\Vorlagen');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zeigt spät geladene Abweichungen ohne aufzuklappen und aktualisiert den Hinweis',
    (tester) async {
      final form = formular();
      await zeige(tester, form);
      form.patchValue({'sicherungsAblageOrdner': r'C:\OneDrive\Sicherung'});
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Abweichende Ablage aktiv: Sicherungen für den Arbeitsplatzwechsel',
        ),
        findsOneWidget,
      );
      expect(find.byType(SicherungsAblageFelder), findsNothing);
      form.patchValue({'sicherungsAblageOrdner': ''});
      await tester.pumpAndSettle();
      expect(find.textContaining('Abweichende Ablage aktiv:'), findsNothing);
      expect(
        find.text('Optional: einzelne Ablageorte abweichend festlegen.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('nennt beim fehlenden Anker die OneDrive-Variable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrdnerZustandZeile(
            zustand: OrdnerZustand(
              feld: 'appDatenOrdner',
              zustand: OrdnerZustandArten.ankerFehlt,
              gespeichert: r'%OneDriveCommercial%\Kanzlei App Daten',
              anker: 'OneDriveCommercial',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FehlerHinweis), findsOneWidget);
    expect(find.textContaining('OneDriveCommercial'), findsOneWidget);
    expect(find.textContaining('nicht auflösen'), findsOneWidget);
  });

  testWidgets('sagt beim fehlenden Ordner, dass er noch entsteht', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrdnerZustandZeile(
            zustand: OrdnerZustand(
              feld: 'sicherungsAblageOrdner',
              zustand: OrdnerZustandArten.ordnerFehlt,
              wirksam: r'C:\OneDrive\Kanzlei App Daten\Sicherungen',
            ),
          ),
        ),
      ),
    );

    expect(
      find.byType(FehlerHinweis),
      findsNothing,
      reason:
          'Angelegt wird beim ersten Schreiben, nicht beim Speichern — das ist '
          'kein Fehler, sondern die Normalform direkt nach der Wahl.',
    );
    expect(
      find.textContaining('beim ersten Schreiben angelegt'),
      findsOneWidget,
    );
  });
}
