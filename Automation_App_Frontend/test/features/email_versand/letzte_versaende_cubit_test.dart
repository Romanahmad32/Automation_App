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
import 'package:automation_app/features/email_versand/presentation/blocs/letzte_versaende_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Versandstand in der Vorgangsliste (§4.7).
///
/// Der Fall, um den es geht: Die App startet den Dienst als Kindprozess. Geht
/// die Vorgangsliste auf, bevor er antwortet, scheitert der eine Abruf — und
/// wenn das Merkmal „schon geladen" **vor** dem Abruf gesetzt wird, erscheint
/// danach zu keinem Vorgang mehr ein Versandstand, die ganze Sitzung lang.
class ProtokollDienst implements EmailVersandRepository {
  /// Wie oft die Liste den Stand angefragt hat. Ein Abruf für alle Zeilen ist
  /// der ganze Zweck des Singletons.
  int abrufe = 0;

  /// Solange gesetzt, scheitert der Abruf — der Dienst fährt noch hoch.
  Object? wirft;

  List<VersandEintrag> eintraege;

  ProtokollDienst({this.eintraege = const [], this.wirft});

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async {
    abrufe++;
    if (wirft != null) throw wirft!;
    return eintraege;
  }

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

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
  Future<void> verwirfAnhang(String pfad) async {}

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];

  @override
  Future<SignaturStand> ladeSignaturStand() async => const SignaturStand();

  @override
  Future<SignaturStand> leseSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> verwirfSignaturFormat() async => const SignaturStand();
}

void main() {
  VersandEintrag eintrag(String referenz) => VersandEintrag(
    vorgangReferenz: referenz,
    gesendetAm: DateTime(2026, 8, 25, 14, 12),
    weg: VersandWeg.direktversand,
  );

  test('ein Abruf für die ganze Liste, auch bei vielen Zeilen', () async {
    final dienst = ProtokollDienst(
      eintraege: [eintrag('84/2026 C03_HG-E 1427')],
    );
    final cubit = LetzteVersaendeCubit(dienst);
    addTearDown(cubit.close);

    // Die Zeilen der Liste gehen alle im selben Rahmen auf — keine wartet auf
    // die Antwort der vorigen.
    await Future.wait([
      cubit.ladenWennNoetig(),
      cubit.ladenWennNoetig(),
      cubit.ladenWennNoetig(),
    ]);
    await cubit.ladenWennNoetig();

    expect(dienst.abrufe, 1);
    expect(cubit.zu('84/2026 C03_HG-E 1427'), isNotNull);
  });

  test('ein gescheiterter Abruf schaltet die Anzeige nicht ab', () async {
    final dienst = ProtokollDienst(wirft: Exception('Dienst startet noch'));
    final cubit = LetzteVersaendeCubit(dienst);
    addTearDown(cubit.close);

    await cubit.ladenWennNoetig();
    expect(cubit.state, isEmpty);

    // Der Dienst steht jetzt. Die nächste Zeile, die aufgeht, muss ihn wieder
    // fragen dürfen — sonst bliebe die Spalte bis zum Neustart der App leer.
    dienst
      ..wirft = null
      ..eintraege = [eintrag('85/2026 C03_HG-E 1428')];

    await cubit.ladenWennNoetig();

    expect(dienst.abrufe, 2);
    expect(cubit.zu('85/2026 C03_HG-E 1428'), isNotNull);
  });

  test('nach einem geglückten Abruf wird nicht erneut gefragt', () async {
    final dienst = ProtokollDienst();
    final cubit = LetzteVersaendeCubit(dienst);
    addTearDown(cubit.close);

    // Auch eine leere Antwort ist eine Antwort: „nichts versendet" heißt nicht
    // „nicht geladen".
    await cubit.ladenWennNoetig();
    await cubit.ladenWennNoetig();

    expect(dienst.abrufe, 1);
  });

  test(
    'neuLaden fragt in jedem Fall — nach einem Versand ist der Stand alt',
    () async {
      final dienst = ProtokollDienst();
      final cubit = LetzteVersaendeCubit(dienst);
      addTearDown(cubit.close);

      await cubit.ladenWennNoetig();
      dienst.eintraege = [eintrag('86/2026 C03_HG-E 1429')];
      await cubit.neuLaden();

      expect(dienst.abrufe, 2);
      expect(cubit.zu('86/2026 C03_HG-E 1429'), isNotNull);
    },
  );

  test('die Referenz wird ohne Rücksicht auf Schreibweise gefunden', () async {
    final dienst = ProtokollDienst(
      eintraege: [eintrag('84/2026 C03_HG-E 1427')],
    );
    final cubit = LetzteVersaendeCubit(dienst);
    addTearDown(cubit.close);

    await cubit.ladenWennNoetig();

    expect(cubit.zu('  84/2026 c03_hg-e 1427 '), isNotNull);
    expect(cubit.zu('99/2026 C03_HG-E 9999'), isNull);
  });
}
