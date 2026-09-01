import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/repositories/mail_vorlagen_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Bestand der Mail-Textvorlagen (§4.7) — ein Singleton, das Verwaltung
/// und Versanddialog teilen.
class VorlagenDienst implements MailVorlagenRepository {
  /// Wie oft der Bestand geholt wurde. Zwei Aufrufer beim Aufgehen dürfen nur
  /// eine Anfrage ergeben, sonst fragt jeder Dialog neu.
  int abrufe = 0;

  List<MailVorlage> bestand;

  /// Solange gesetzt, scheitert das Schreiben — der Fall „Name schon vergeben".
  Object? wirftBeimSchreiben;

  /// Solange gesetzt, scheitert der Abruf — der Dienst faehrt noch hoch.
  Object? wirftBeimLaden;

  VorlagenDienst({
    this.bestand = const [],
    this.wirftBeimSchreiben,
    this.wirftBeimLaden,
  });

  @override
  Future<List<MailVorlage>> ladeVorlagen() async {
    abrufe++;
    if (wirftBeimLaden != null) throw wirftBeimLaden!;
    return bestand;
  }

  @override
  Future<MailVorlage> lege(MailVorlage vorlage) async {
    if (wirftBeimSchreiben != null) throw wirftBeimSchreiben!;
    final angelegt = MailVorlage(
      id: bestand.length + 1,
      name: vorlage.name,
      betreff: vorlage.betreff,
      text: vorlage.text,
    );
    bestand = [...bestand, angelegt];
    return angelegt;
  }

  @override
  Future<MailVorlage> aktualisiere(MailVorlage vorlage) async {
    if (wirftBeimSchreiben != null) throw wirftBeimSchreiben!;
    bestand = [
      for (final vorhanden in bestand)
        vorhanden.id == vorlage.id ? vorlage : vorhanden,
    ];
    return vorlage;
  }

  @override
  Future<void> loesche(int id) async {
    bestand = [
      for (final vorhanden in bestand)
        if (vorhanden.id != id) vorhanden,
    ];
  }
}

void main() {
  const anschreiben = MailVorlage(
    id: 1,
    name: 'Anschreiben an den Mandanten',
    betreff: 'Ihre Verkehrsunfallsache',
    text: '{{Anrede}},',
  );

  test(
    'holt den Bestand einmal, auch wenn zwei Stellen ihn brauchen',
    () async {
      final dienst = VorlagenDienst(bestand: const [anschreiben]);
      final cubit = MailVorlagenCubit(dienst);

      await Future.wait([cubit.ladenWennNoetig(), cubit.ladenWennNoetig()]);
      await cubit.ladenWennNoetig();

      expect(dienst.abrufe, 1);
      expect(cubit.state.vorlagen, [anschreiben]);
      expect(cubit.state.geladen, isTrue);
    },
  );

  test('ein gescheiterter Abruf sperrt den Bestand nicht dauerhaft', () async {
    // Die App startet den Dienst als Kindprozess: Gehen die Einstellungen auf,
    // bevor er antwortet, scheitert genau dieser erste Abruf. Wuerde dabei
    // schon „geladen" gesetzt, bliebe die Verwaltung die ganze Sitzung leer.
    final dienst = VorlagenDienst(
      bestand: const [anschreiben],
      wirftBeimLaden: Exception('Der Dienst ist nicht erreichbar'),
    );
    final cubit = MailVorlagenCubit(dienst);

    await cubit.ladenWennNoetig();
    expect(cubit.state.geladen, isFalse);
    expect(cubit.state.fehler, contains('nicht erreichbar'));

    dienst.wirftBeimLaden = null;
    await cubit.ladenWennNoetig();

    expect(dienst.abrufe, 2, reason: 'der zweite Versuch muss stattfinden');
    expect(cubit.state.vorlagen, [anschreiben]);
    expect(cubit.state.fehler, isNull);
  });

  test('nach dem Speichern steht der neue Bestand', () async {
    final dienst = VorlagenDienst();
    final cubit = MailVorlagenCubit(dienst);

    final geglueckt = await cubit.speichere(
      const MailVorlage(name: 'Nachfrage an die Versicherung'),
    );

    expect(geglueckt, isTrue);
    expect(cubit.state.vorlagen.single.name, 'Nachfrage an die Versicherung');
    expect(cubit.state.fehler, isNull);
  });

  test(
    'ein vergebener Name meldet Klartext und laesst den Bestand stehen',
    () async {
      final dienst = VorlagenDienst(
        bestand: const [anschreiben],
        wirftBeimSchreiben: Exception(
          'Eine Mail-Vorlage mit dem Namen Anschreiben an den Mandanten gibt es bereits',
        ),
      );
      final cubit = MailVorlagenCubit(dienst);
      await cubit.ladenWennNoetig();

      final geglueckt = await cubit.speichere(
        const MailVorlage(name: 'Anschreiben an den Mandanten'),
      );

      expect(
        geglueckt,
        isFalse,
        reason: 'der Dialog darf sich nicht schliessen',
      );
      expect(cubit.state.fehler, isNot(startsWith('Exception')));
      expect(cubit.state.fehler, contains('gibt es bereits'));
      expect(cubit.state.vorlagen, [anschreiben], reason: 'die Liste bleibt');
    },
  );

  test('entfernen nimmt die Vorlage aus dem Bestand', () async {
    final dienst = VorlagenDienst(bestand: const [anschreiben]);
    final cubit = MailVorlagenCubit(dienst);
    await cubit.ladenWennNoetig();

    await cubit.loesche(anschreiben.id);

    expect(cubit.state.vorlagen, isEmpty);
  });
}
