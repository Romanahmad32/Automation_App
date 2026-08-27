import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bilder der Signatur je Mail an- und abwählen (§4.7).
///
/// Der Anlass ist der Alltag der Kanzlei: In der Signatur hängt ein animiertes
/// Werbebild von mehreren Megabyte, das nicht unter jede Nachricht gehört.
/// Entscheidend ist, dass die Abwahl auch **zählt** — sonst bliebe die
/// Nachricht zu groß, und die Entscheidung wäre folgenlos.
void main() {
  const logo = SignaturBild(dateiname: 'logo.png', bytes: 20 * 1024);
  const werbung = SignaturBild(
    dateiname: 'werbung.gif',
    bytes: 6 * 1024 * 1024,
  );

  const bereit = EmailVersandBereitschaft(
    bereit: true,
    absender: 'kanzlei@example.de',
    signaturBilder: [logo, werbung],
    maxAnhangMb: 10,
  );

  const entwurf = EmailEntwurf(
    an: ['gegner@example.de'],
    betreff: 'Anspruchsschreiben',
  );

  test('ohne Abwahl gehen alle Bilder mit', () {
    const zustand = EmailEntwurfState(entwurf: entwurf, bereitschaft: bereit);

    expect(zustand.signaturBytes, logo.bytes + werbung.bytes);
  });

  test('ein abgewaehltes Bild zaehlt nicht mehr mit', () {
    final zustand = EmailEntwurfState(
      entwurf: entwurf.mitUmgeschaltetemSignaturBild('werbung.gif'),
      bereitschaft: bereit,
    );

    expect(zustand.signaturBytes, logo.bytes);
  });

  test('umschalten nimmt es auch wieder hinein', () {
    final wieder = entwurf
        .mitUmgeschaltetemSignaturBild('werbung.gif')
        .mitUmgeschaltetemSignaturBild('werbung.gif');

    expect(wieder.ohneSignaturBilder, isEmpty);
    expect(wieder.signaturBildGehtMit('werbung.gif'), isTrue);
  });

  test('die Signaturbilder entscheiden ueber die Grenze mit', () {
    // 5 MB Anhaenge plus 6 MB Werbebild reissen die 10-MB-Grenze; ohne das
    // Werbebild passt dieselbe Mail.
    const mitWerbung = EmailEntwurfState(
      entwurf: entwurf,
      bereitschaft: bereit,
      anhangBytes: 5 * 1024 * 1024,
    );
    expect(mitWerbung.ueberGrenze, isTrue);
    expect(mitWerbung.kannSenden, isFalse);

    final ohneWerbung = EmailEntwurfState(
      entwurf: entwurf.mitUmgeschaltetemSignaturBild('werbung.gif'),
      bereitschaft: bereit,
      anhangBytes: 5 * 1024 * 1024,
    );
    expect(ohneWerbung.ueberGrenze, isFalse);
    expect(ohneWerbung.kannSenden, isTrue);
  });

  test('die Abwahl geht als ohneSignaturBilder ans Backend', () {
    final json = entwurf
        .mitUmgeschaltetemSignaturBild('werbung.gif')
        .toJson('Kanzlei Ahmad');

    expect(json['ohneSignaturBilder'], ['werbung.gif']);
  });
}
