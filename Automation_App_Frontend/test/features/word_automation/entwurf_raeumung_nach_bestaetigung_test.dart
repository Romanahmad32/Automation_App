import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/word_automation/presentation/utils/entwurf_raeumung_nach_bestaetigung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review-Nachbesserung zu #133, Befund 4: `word_automation_page.dart` rief
/// `VorgangCubit.sichereEntwurf(referenz, null)` bisher auch dann, wenn am
/// Vorgang gar kein Entwurf lag — ein DELETE ins Leere, das `entwurfs_
/// sicherung.dart` an vergleichbarer Stelle längst vermeidet.
void main() {
  Vorgang vorgang({VorgangEntwurf? entwurf}) => Vorgang.ausAnfrage(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 6, 1),
  ).copyWith(entwurf: () => entwurf);

  final entwurf = VorgangEntwurf(
    gespeichertAm: DateTime(2026, 6, 2),
    feldWerte: const {'Versicherer': 'HUK'},
  );

  test('ohne bestätigten Stand wird nichts geräumt', () {
    expect(sollEntwurfGeraeumtWerden(null, vorgang(entwurf: entwurf)), isFalse);
  });

  test(
    'mit bestätigtem Stand, aber ohne Entwurf am Vorgang: nichts zu tun',
    () {
      expect(
        sollEntwurfGeraeumtWerden(const {'Versicherer': 'HUK'}, vorgang()),
        isFalse,
      );
    },
  );

  test('mit bestätigtem Stand und Entwurf am Vorgang wird geräumt', () {
    expect(
      sollEntwurfGeraeumtWerden(const {
        'Versicherer': 'HUK',
      }, vorgang(entwurf: entwurf)),
      isTrue,
    );
  });
}
