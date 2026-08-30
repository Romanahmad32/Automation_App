import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Antwortet mit einem festen Stand und merkt sich, wie gefragt wurde.
class RegisterSpiegelAttrappe implements RegisterSpiegelRepository {
  final RegisterSpiegelErgebnis antwort;
  final Object? wirft;

  bool? letztesErzwingen;
  int standAbrufe = 0;

  RegisterSpiegelAttrappe({
    this.antwort = const RegisterSpiegelErgebnis(),
    this.wirft,
  });

  @override
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen = true}) async {
    letztesErzwingen = erzwingen;
    if (wirft != null) throw wirft!;
    return antwort;
  }

  @override
  Future<RegisterSpiegelErgebnis> ladeStand() async {
    standAbrufe++;
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
    final cubit = RegisterSpiegelCubit(attrappe);

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
    final cubit = RegisterSpiegelCubit(attrappe);

    await cubit.exportiere();

    expect(attrappe.letztesErzwingen, isTrue);
    expect(cubit.state.geschrieben, isTrue);
  });

  test('ein nicht erreichbarer Dienst wird zu einem lesbaren Satz', () async {
    final cubit = RegisterSpiegelCubit(
      RegisterSpiegelAttrappe(wirft: Exception('Verbindung abgelehnt')),
    );

    await cubit.exportiere();

    expect(cubit.state.fehler, contains('nicht erreichbar'));
    expect(cubit.state.geschrieben, isFalse);
  });

  test(
    'laeuft ist nach dem Lauf wieder false — auch nach einem Fehler',
    () async {
      final cubit = RegisterSpiegelCubit(
        RegisterSpiegelAttrappe(wirft: Exception('Zeitüberschreitung')),
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
      'zeilen': 3,
      'geschriebenAm': '2026-08-30T12:00:00',
      'konfliktkopien': ['Register-LAPTOP.docx'],
    });

    expect(stand.geschrieben, isTrue);
    expect(stand.zeilen, 3);
    expect(stand.geschriebenAm, DateTime(2026, 8, 30, 12));
    expect(stand.konfliktkopien, ['Register-LAPTOP.docx']);
  });

  test('fromJson kommt mit einer knappen Antwort aus', () {
    final stand = RegisterSpiegelErgebnis.fromJson(const {
      'geschrieben': false,
    });

    expect(stand.zeilen, 0);
    expect(stand.geschriebenAm, isNull);
    expect(stand.konfliktkopien, isEmpty);
  });
}
