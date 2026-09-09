import 'dart:async';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Antwortet mit einem festen Stand und merkt sich, wie gefragt wurde.
class RegisterSpiegelAttrappe implements RegisterSpiegelRepository {
  final RegisterSpiegelErgebnis antwort;
  final Object? wirft;

  /// Hält `ladeStand` an, bis der Test sie freigibt — damit ein Knopfdruck
  /// *währenddessen* prüfbar wird.
  final Completer<void>? standHaengt;

  bool? letztesErzwingen;
  int standAbrufe = 0;
  int exportAufrufe = 0;

  RegisterSpiegelAttrappe({
    this.antwort = const RegisterSpiegelErgebnis(),
    this.wirft,
    this.standHaengt,
  });

  @override
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen = true}) async {
    exportAufrufe++;
    letztesErzwingen = erzwingen;
    if (wirft != null) throw wirft!;
    return antwort;
  }

  @override
  Future<RegisterSpiegelErgebnis> ladeStand() async {
    standAbrufe++;
    if (standHaengt != null) await standHaengt!.future;
    if (wirft != null) throw wirft!;
    return antwort;
  }
}

void main() {
  test('ladeStand übernimmt den Stand aus dem Dienst', () async {
    final attrappe = RegisterSpiegelAttrappe(
      antwort: const RegisterSpiegelErgebnis(
        zeilen: 12,
        docxPfad: 'C:/OneDrive/R.docx',
      ),
    );
    final cubit = RegisterSpiegelCubit(attrappe, FakeRegisterPushNotifier());

    await cubit.ladeStand();

    expect(cubit.state.zeilen, 12);
    expect(cubit.state.docxPfad, 'C:/OneDrive/R.docx');
  });

  /// Hinter dem Knopf steht in aller Regel „die Datei ist weg oder sieht falsch
  /// aus". Ein „nichts zu tun" wäre darauf die unbrauchbarste aller Antworten —
  /// deshalb erzwingt der Knopf, der automatische Lauf nach dem Abschluss nicht.
  test('der Knopf schreibt auch einen unveränderten Bestand', () async {
    final attrappe = RegisterSpiegelAttrappe(
      antwort: const RegisterSpiegelErgebnis(geschrieben: true),
    );
    final cubit = RegisterSpiegelCubit(attrappe, FakeRegisterPushNotifier());

    await cubit.exportiere();

    expect(attrappe.letztesErzwingen, isTrue);
    expect(cubit.state.geschrieben, isTrue);
  });

  /// Die Datenquelle hat den Fehlschlag der Leitung schon in einen deutschen
  /// Satz übersetzt — der geht unverändert an den Anwalt.
  test('der Satz der Datenquelle kommt unverändert durch', () async {
    final cubit = RegisterSpiegelCubit(
      RegisterSpiegelAttrappe(
        wirft: const RegisterException(
          'Der Dienst der Anwendung antwortet nicht. '
          'Bitte starten Sie die Anwendung neu.',
        ),
      ),
      FakeRegisterPushNotifier(),
    );

    await cubit.exportiere();

    expect(cubit.state.fehler, startsWith('Der Dienst der Anwendung'));
    expect(cubit.state.geschrieben, isFalse);
  });

  /// Der Fall, den es nicht geben sollte: eine Ausnahme, die niemand übersetzt
  /// hat. Ihr Text stand vorher wortwörtlich in der Meldung („DioException
  /// [connection error] …") — und der sagt dem Anwalt nichts.
  test(
    'eine unübersetzte Ausnahme landet nicht im Wortlaut am Bildschirm',
    () async {
      final cubit = RegisterSpiegelCubit(
        RegisterSpiegelAttrappe(wirft: Exception('DioException [unknown]')),
        FakeRegisterPushNotifier(),
      );

      await cubit.exportiere();

      expect(cubit.state.fehler, isNot(contains('DioException')));
      expect(cubit.state.fehler, contains('nicht geschrieben werden'));
    },
  );

  /// Der Knopf gilt auch dann, wenn die Seite gerade erst aufgeht.
  ///
  /// `ladeStand()` startet beim Öffnen des Registers und dauert eine
  /// Netzwerkrunde. Ein Druck in dieser Sekunde wurde vorher stillschweigend
  /// verworfen: Der Knopf blinkte kurz, danach stand derselbe Stand da wie
  /// zuvor, und niemand erfuhr, warum nichts geschah.
  test(
    'ein Knopfdruck während ladeStand wird eingereiht, nicht verworfen',
    () async {
      final tor = Completer<void>();
      final attrappe = RegisterSpiegelAttrappe(
        antwort: const RegisterSpiegelErgebnis(geschrieben: true),
        standHaengt: tor,
      );
      final cubit = RegisterSpiegelCubit(attrappe, FakeRegisterPushNotifier());

      final laden = cubit.ladeStand();
      final druck = cubit.exportiere();
      tor.complete();
      await Future.wait([laden, druck]);

      expect(attrappe.exportAufrufe, 1, reason: 'der Druck kommt durch');
      expect(cubit.state.geschrieben, isTrue);
      expect(cubit.laeuft, isFalse);
    },
  );

  test(
    'laeuft ist nach dem Lauf wieder false — auch nach einem Fehler',
    () async {
      final cubit = RegisterSpiegelCubit(
        RegisterSpiegelAttrappe(wirft: Exception('Zeitüberschreitung')),
        FakeRegisterPushNotifier(),
      );

      await cubit.exportiere();

      expect(cubit.laeuft, isFalse);
    },
  );

  test('fromJson liest den Stand des Dienstes', () {
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': true,
      'grund': null,
      'fehler': null,
      'docxPfad': r'C:\OneDrive\Register.docx',
      'pdfPfad': r'C:\OneDrive\Register.pdf',
      'pdfFehler': null,
      'pdfLaeuft': false,
      'zeilen': 3,
      'geschriebenAm': '2026-08-30T12:00:00',
      'konfliktkopien': ['Register-LAPTOP.docx'],
    });

    expect(stand.geschrieben, isTrue);
    expect(stand.zeilen, 3);
    expect(stand.geschriebenAm, DateTime(2026, 8, 30, 12));
    expect(stand.konfliktkopien, ['Register-LAPTOP.docx']);
  });

  /// §6.2 „Word sofort, PDF nachgezogen": Direkt nach dem Export gilt
  /// regelmäßig `pdfPfad: null`, `pdfFehler: null`, `pdfLaeuft: true`.
  test('fromJson liest pdfLaeuft', () {
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': true,
      'docxPfad': r'C:\OneDrive\Register.docx',
      'pdfPfad': null,
      'pdfFehler': null,
      'pdfLaeuft': true,
    });

    expect(stand.pdfLaeuft, isTrue);
    expect(stand.pdfPfad, isNull);
    expect(stand.pdfFehler, isNull);
  });

  test('fromJson nimmt an, dass keine PDF-Umwandlung läuft', () {
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': false,
    });

    expect(stand.pdfLaeuft, isFalse);
  });

  test('fromJson rechnet den Versatz des Dienstes in Ortszeit um', () {
    // Der Dienst sendet `DateTime.Now`, also mit Zeitzonenversatz. `DateTime`
    // parst das zu einem UTC-Wert; ohne `toLocal()` nennt die Fußleiste zwei
    // Stunden früher als die Uhrzeit, die im geschriebenen Dokument selbst
    // steht („Stand 09.09.2026 13:34" gegen „· 11:34"). Genau daran ist der
    // Verdacht entstanden, die App habe gar nicht geschrieben.
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': true,
      'geschriebenAm': '2026-09-09T13:34:10.3894212+02:00',
    });

    expect(stand.geschriebenAm!.isUtc, isFalse);
    expect(
      stand.geschriebenAm,
      DateTime.parse('2026-09-09T13:34:10.3894212+02:00').toLocal(),
    );
  });

  test('fromJson kommt mit einer knappen Antwort aus', () {
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': false,
    });

    expect(stand.zeilen, 0);
    expect(stand.geschriebenAm, isNull);
    expect(stand.konfliktkopien, isEmpty);
  });

  group('Hub-Meldung registerPdfFertig', () {
    // §6.2: „Dass ein PDF gerade entsteht, ist an der Oberfläche ablesbar" —
    // der Cubit trägt die Meldung nach, statt dass die Seite im Takt fragt.
    test('fertig: true trägt Pfad nach und beendet pdfLaeuft', () async {
      final hub = FakeRegisterPushNotifier();
      final cubit = RegisterSpiegelCubit(
        RegisterSpiegelAttrappe(
          antwort: const RegisterSpiegelErgebnis(
            geschrieben: true,
            docxPfad: r'C:\OneDrive\Register.docx',
            pdfLaeuft: true,
          ),
        ),
        hub,
      );
      await cubit.exportiere();
      expect(cubit.state.pdfLaeuft, isTrue);

      hub.sendePdfFertig(fertig: true, pdfPfad: r'C:\OneDrive\Register.pdf');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.pdfLaeuft, isFalse);
      expect(cubit.state.pdfPfad, r'C:\OneDrive\Register.pdf');
      expect(cubit.state.pdfFehler, isNull);
      // Der Rest des Stands bleibt unberührt.
      expect(cubit.state.docxPfad, r'C:\OneDrive\Register.docx');
    });

    test(
      'fertig: false trägt den Klartext aus fehler nach — kein Fehlschlag',
      () async {
        final hub = FakeRegisterPushNotifier();
        final cubit = RegisterSpiegelCubit(
          RegisterSpiegelAttrappe(
            antwort: const RegisterSpiegelErgebnis(
              geschrieben: true,
              pdfLaeuft: true,
            ),
          ),
          hub,
        );
        await cubit.exportiere();

        hub.sendePdfFertig(
          fertig: false,
          fehler: 'Word ist auf diesem Rechner nicht installiert.',
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.pdfLaeuft, isFalse);
        expect(
          cubit.state.pdfFehler,
          'Word ist auf diesem Rechner nicht installiert.',
        );
        expect(cubit.state.pdfPfad, isNull);
        // Kein Fehlschlag des Spiegels — nur des PDFs daneben.
        expect(cubit.state.fehler, isNull);
      },
    );
  });
}
