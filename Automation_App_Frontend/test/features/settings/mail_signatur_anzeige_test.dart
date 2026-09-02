import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_signatur_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_vorgemerkt_zeile.dart';
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

  /// Was der Import aus Outlook liest — und wer danach gefragt hat.
  SignaturStand gelesen = const SignaturStand();

  final List<String> geleseneNamen = [];

  /// Die Namen, fuer die tatsaechlich **uebernommen** (also geschrieben)
  /// wurde. Genau daran haengt der behobene Mangel: Vorher stand hier schon
  /// nach dem Lesen ein Eintrag.
  final List<String> uebernommeneNamen = [];

  /// Wie oft die Formatierung samt Bildern verworfen wurde.
  int verworfen = 0;

  @override
  Future<SignaturStand> leseSignatur(String name) async {
    geleseneNamen.add(name);
    return gelesen;
  }

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async {
    uebernommeneNamen.add(name);
    stand = gelesen;
    return gelesen;
  }

  @override
  Future<SignaturStand> verwirfSignaturFormat() async {
    verworfen++;
    stand = const SignaturStand();
    return stand;
  }
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

  /// Die zwei Traeger, die sonst der Einstellungsseite gehoeren: Feldtext und
  /// vorgemerkte Uebernahme. Der Test haelt sie selbst, weil er beides prueft.
  late TextEditingController feld;
  late ValueNotifier<String> vorgemerkt;

  Future<void> zeige(WidgetTester tester, KanzleiSettingsBloc bloc) async {
    feld = TextEditingController();
    vorgemerkt = ValueNotifier<String>('');
    addTearDown(feld.dispose);
    addTearDown(vorgemerkt.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: SingleChildScrollView(
              child: MailSignaturSektion(
                controller: feld,
                vorgemerkt: vorgemerkt,
              ),
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

  /// Ein geladener Bloc auf dem gepflegten Stand — die Ausgangslage beider
  /// Gruppen darunter.
  KanzleiSettingsBloc bauBloc() {
    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  group('der Import schreibt nicht mehr selbst (§4.7)', () {
    const ausOutlook = SignaturStand(
      text: 'Rechtsanwalt Roman Ahmad',
      html: '<p>Rechtsanwalt Roman Ahmad</p>',
      bilder: [SignaturBild(dateiname: 'logo.png', bytes: 4096)],
    );

    testWidgets('Lesen füllt das Feld und merkt den Namen vor', (tester) async {
      dienst.gelesen = ausOutlook;
      final bloc = bauBloc();
      await zeige(tester, bloc);
      bloc.add(const LoadKanzleiSettingsEvent());
      await tester.pumpAndSettle();

      // Den Weg über den Auswahldialog spart der Test: Was hier zählt, ist,
      // was der Abschnitt mit dem Gelesenen macht.
      final sektion = tester.widget<MailSignaturSektion>(
        find.byType(MailSignaturSektion),
      );
      expect(sektion.vorgemerkt, same(vorgemerkt));

      await MailSignaturSektion.speichereWennGeaendert(
        tester.element(find.byType(MailSignaturSektion)),
        'Von Hand geändert',
        vorgemerkt,
      );
      await tester.pumpAndSettle();

      expect(
        dienst.uebernommeneNamen,
        isEmpty,
        reason: 'ohne vorgemerkten Namen ist nichts zu übernehmen',
      );
    });

    testWidgets('erst das Speichern übernimmt — und der Feldtext gewinnt', (
      tester,
    ) async {
      dienst.gelesen = ausOutlook;
      final bloc = bauBloc();
      await zeige(tester, bloc);
      bloc.add(const LoadKanzleiSettingsEvent());
      await tester.pumpAndSettle();

      vorgemerkt.value = 'Kanzlei';
      feld.text = 'Von Hand nachgeschärft';
      await MailSignaturSektion.speichereWennGeaendert(
        tester.element(find.byType(MailSignaturSektion)),
        feld.text,
        vorgemerkt,
      );
      await tester.pumpAndSettle();

      expect(dienst.uebernommeneNamen, ['Kanzlei']);
      expect(
        vorgemerkt.value,
        isEmpty,
        reason:
            'die Vormerkung ist eingelöst und darf nicht ein zweites Mal '
            'greifen',
      );
    });

    testWidgets('der Hinweis sagt, dass noch nichts geschrieben ist', (
      tester,
    ) async {
      expect(
        SignaturVorgemerktZeile.text('Kanzlei', mitBildern: true),
        allOf(
          contains('Kanzlei'),
          contains('erst mit „Speichern"'),
          contains('bisherige Signatur'),
        ),
      );
      expect(
        SignaturVorgemerktZeile.text('Kanzlei', mitBildern: false),
        isNot(contains('Bilder')),
        reason:
            'ohne Bilder fehlt in der Vorschau nichts — dann kein Satz '
            'dazu',
      );
    });
  });

  group('die Signatur ganz entfernen (§4.7)', () {
    testWidgets('nimmt Text, Formatierung und Bilder mit', (tester) async {
      // Der Mangel: Das Feld zu leeren entfernte nur die Nur-Text-Fassung.
      // Die HTML-Fassung blieb stehen, und weil die Mail sie bevorzugt, ging
      // die Signatur samt Logo weiter unter jeder Mail hinaus.
      dienst.stand = const SignaturStand(
        text: 'Kanzlei Ahmad',
        html: '<p>Kanzlei Ahmad</p>',
        bilder: [SignaturBild(dateiname: 'logo.png', bytes: 4096)],
      );
      final gespeicherte = <String>[];
      final bloc = KanzleiSettingsBloc(
        FesterSettingsAbruf(gespeichert),
        DurchreichendesSpeichern(),
      );
      addTearDown(bloc.close);
      bloc.stream.listen((zustand) {
        if (zustand is KanzleiSettingsLoaded &&
            zustand.gespeichert == KanzleiSettingsBereich.signatur) {
          gespeicherte.add(zustand.settings.mailSignatur);
        }
      });

      await zeige(tester, bloc);
      bloc.add(const LoadKanzleiSettingsEvent());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signatur entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();

      expect(
        dienst.verworfen,
        1,
        reason: 'Formatierung und Bilder liegen im Dienst',
      );
      expect(imFeld(tester), isEmpty);
      expect(gespeicherte, [
        '',
      ], reason: 'und der leere Text muss auch geschrieben werden');
    });

    testWidgets('fragt vorher, denn nichts davon kommt zurück', (tester) async {
      final bloc = bauBloc();
      await zeige(tester, bloc);
      bloc.add(const LoadKanzleiSettingsEvent());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signatur entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(dienst.verworfen, 0);
      expect(imFeld(tester), gespeichert.mailSignatur);
    });
  });
}
