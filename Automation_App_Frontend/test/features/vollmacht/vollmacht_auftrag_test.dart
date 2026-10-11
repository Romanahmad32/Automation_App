import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wann zwei Vollmacht-Aufträge gleich sind (§4.11). Daran hängen die
/// Vorschau (neu bestellt nur bei einem anderen Auftrag) und „In Word öffnen"
/// (dieselbe Datei erneut öffnen statt neu ausfüllen, #174).
void main() {
  VollmachtAuftrag auftrag(VollmachtKopfdaten kopf) => VollmachtAuftrag(
    art: VollmachtArt.bussgeldsachen,
    referenz: '84/26 C03o_GG-XY 123',
    kopfdaten: kopf,
  );

  const vonHand = VollmachtKopfdaten(
    nachname: 'Muster',
    wegen: 'Vorwurf der OWi. vom Mai',
  );

  test('ein anderes Tatdatum bei handgeschriebenem „wegen" ist derselbe '
      'Auftrag', () {
    // Das Tatdatum geht nicht an den Dienst; am Papier ändert es nur etwas
    // über „wegen". Sonst füllte „In Word öffnen" neu aus und träfe womöglich
    // auf die Datei, die Word noch offen hält.
    expect(auftrag(vonHand.copyWith(tatdatum: '03.10.2026')), auftrag(vonHand));
  });

  test('was an den Dienst geht, unterscheidet', () {
    expect(
      auftrag(vonHand.copyWith(wegen: 'Vorwurf der OWi. am 03.10.2026')),
      isNot(auftrag(vonHand)),
    );
    expect(auftrag(vonHand.copyWith(vorname: 'Max')), isNot(auftrag(vonHand)));
  });
}
