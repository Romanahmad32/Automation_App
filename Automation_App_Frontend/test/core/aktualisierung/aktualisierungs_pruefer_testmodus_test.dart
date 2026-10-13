import 'dart:io';

import 'package:automation_app/core/aktualisierung/aktualisierungs_pruefer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Merkt sich, ob jemand einen HTTP-Client verlangt hat, und verweigert ihn.
class ZaehlendeHttpOverrides extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw const SocketException('Im Test kein Netz.');
  }
}

void main() {
  group('AktualisierungsPruefer im Testmodus', () {
    test('fragt GitHub nicht an und meldet keine Neuerung', () async {
      final netz = ZaehlendeHttpOverrides();

      final ergebnis = await HttpOverrides.runWithHttpOverrides(
        () =>
            const AktualisierungsPruefer(testmodusErwartet: true)
                .pruefen('1.0.0'),
        netz,
      );

      // Im Testmodus geht nichts nach außen — auch keine Update-Anfrage.
      expect(netz.clients, 0);
      expect(ergebnis.neueVersion, isNull);
    });

    test('ohne Testmodus wird weiter angefragt', () async {
      final netz = ZaehlendeHttpOverrides();

      // Die Attrappe wirft schon beim Anlegen des Clients; entscheidend ist,
      // dass er überhaupt verlangt wird.
      await expectLater(
        HttpOverrides.runWithHttpOverrides(
          () =>
              const AktualisierungsPruefer(testmodusErwartet: false)
                  .pruefen('1.0.0'),
          netz,
        ),
        throwsA(isA<SocketException>()),
      );

      expect(netz.clients, 1);
    });
  });
}
