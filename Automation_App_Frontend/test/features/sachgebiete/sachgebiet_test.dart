import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson liest jedes Feld des SachgebietDto', () {
    final sachgebiet = Sachgebiet.fromJson(const {
      'id': 5,
      'kuerzel': 'C03o',
      'name': 'Ordnungswidrigkeitssache',
      'rechtsgebietVorschlag': 'Ordnungswidrigkeitssache',
      'sortierung': 50,
      'aktiv': true,
    });

    expect(
      sachgebiet,
      const Sachgebiet(
        id: 5,
        kuerzel: 'C03o',
        name: 'Ordnungswidrigkeitssache',
        rechtsgebietVorschlag: 'Ordnungswidrigkeitssache',
        sortierung: 50,
        aktiv: true,
      ),
    );
  });
}
