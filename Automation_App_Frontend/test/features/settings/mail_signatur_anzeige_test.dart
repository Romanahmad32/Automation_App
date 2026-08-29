import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_signatur_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'kanzlei_settings_doubles.dart';

/// Die gespeicherte Signatur muss im Feld stehen, **wann immer** der Abschnitt
/// aufgeht — auch beim zweiten Mal.
///
/// Der Fall, der in der Kanzlei auffiel: Beim zweiten Öffnen des E-Mail-Reiters
/// war das Feld leer. Der Abschnitt zog den Stand nur aus dem Bloc-*Übergang*
/// nach Loaded; beim zweiten Mal stand der Bloc längst auf Loaded, es gab
/// keinen Übergang mehr, und niemand las den vorhandenen Zustand. Wer dann auf
/// „Speichern" drückte, schrieb die leere Fassung über die gepflegte.
class LeererSignaturDienst implements EmailVersandRepository {
  /// Was der Dienst als Signaturstand liefert.
  SignaturStand stand;

  LeererSignaturDienst({this.stand = const SignaturStand()});

  @override
  Future<SignaturStand> ladeSignaturStand() async => stand;

  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async =>
      const EmailVersandBereitschaft(bereit: false);

  @override
  Future<EmailVersandErgebnis> sende(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) => throw UnimplementedError();

  @override
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) => throw UnimplementedError();

  @override
  Future<void> waermeEntwurfVor() async {}

  @override
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() async =>
      const OutlookAnhaenge();

  @override
  Future<OutlookStand> ladeOutlookStand() async => OutlookStand.unbekannt;

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];

  @override
  Future<void> verwirfAnhang(String pfad) async {}

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> verwirfSignaturFormat() async => const SignaturStand();
}

void main() {
  const gespeichert = KanzleiSettings(
    name: 'Kanzlei Ahmad',
    mailSignatur: 'Mit freundlichen Grüßen\nKanzlei Ahmad',
  );

  late LeererSignaturDienst dienst;

  setUp(() {
    dienst = LeererSignaturDienst();
    getIt.registerSingleton<EmailVersandRepository>(dienst);
  });

  tearDown(() => getIt.reset());

  /// Was im Eingabefeld steht — nicht, was irgendwo auf dem Schirm steht: Die
  /// Vorschau darunter zeigt denselben Text, und genau das Feld ist es, das
  /// beim Speichern gelesen wird.
  String imFeld(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '';

  Future<void> zeige(WidgetTester tester, KanzleiSettingsBloc bloc) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: SingleChildScrollView(
              child: MailSignaturSektion(controller: TextEditingController()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt die gespeicherte Signatur beim ersten Öffnen', (
    tester,
  ) async {
    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);

    await zeige(tester, bloc);
    bloc.add(const LoadKanzleiSettingsEvent());
    await tester.pumpAndSettle();

    expect(imFeld(tester), gespeichert.mailSignatur);
  });

  testWidgets('zeigt sie auch, wenn der Bloc schon geladen war', (
    tester,
  ) async {
    // Der zweite Aufruf: Die Einstellungen sind langst geladen, der Abschnitt
    // geht neu auf. Es kommt kein Uebergang mehr, aus dem er den Stand
    // aufschnappen koennte.
    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);
    final geladen = bloc.stream.firstWhere((s) => s is KanzleiSettingsLoaded);
    bloc.add(const LoadKanzleiSettingsEvent());
    await geladen;

    await zeige(tester, bloc);

    expect(imFeld(tester), gespeichert.mailSignatur);
  });

  testWidgets('rendert die formatierte Fassung, nicht die Nur-Text-Fassung', (
    tester,
  ) async {
    // Outlook fuehrt die Signatur doppelt: als HTML mit Schrift und Farben und
    // daneben als eigene Nur-Text-Uebersetzung. Beim Empfaenger kommt die
    // erste an -- also muss die Einstellungsmaske sie zeigen.
    //
    // Der Fehler, den dieser Test festhaelt, war stumm: Die Vorschau bekam das
    // HTML gar nicht durchgereicht. Weil der Parameter einen Standardwert hat,
    // uebersetzte alles und die Analyse schwieg -- zu sehen war nur, dass die
    // Einstellungen anders aussahen als der Versanddialog.
    dienst.stand = const SignaturStand(
      text: 'Mit freundlichen Grüßen\nKanzlei Ahmad',
      hatFormat: true,
      html: '<p><b>Kanzlei Ahmad</b></p>',
    );

    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);
    final geladen = bloc.stream.firstWhere((s) => s is KanzleiSettingsLoaded);
    bloc.add(const LoadKanzleiSettingsEvent());
    await geladen;

    await zeige(tester, bloc);

    expect(find.byType(HtmlWidget), findsOneWidget);
  });
}
