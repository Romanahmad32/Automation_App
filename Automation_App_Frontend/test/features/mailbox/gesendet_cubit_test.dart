import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mailbox_doubles.dart';

/// Der Bereich „Gesendet" (§4.3) beantwortet „Was ist heute rausgegangen?" —
/// über alle Vorgänge hinweg, das Jüngste zuerst.
void main() {
  final eintraege = [
    VersandEintrag(
      vorgangReferenz: '144/26 C03',
      gesendetAm: DateTime(2026, 9, 13, 11, 5),
      weg: VersandWeg.direktversand,
      empfaenger: const ['schaden@huk.de'],
      betreff: 'Anspruchsschreiben 144/26 C03',
    ),
    VersandEintrag(
      vorgangReferenz: '145/26 C03',
      gesendetAm: DateTime(2026, 9, 12, 16, 40),
      weg: VersandWeg.outlookEntwurf,
      empfaenger: const ['post@allianz.de'],
      betreff: 'Anspruchsschreiben 145/26 C03',
    ),
  ];

  test('laedt die Versaende und reicht das Limit durch', () async {
    final protokoll = VersandTestProtokoll(eintraege: eintraege);
    final cubit = GesendetCubit(protokoll);
    addTearDown(cubit.close);

    await cubit.laden(limit: 50);

    expect(cubit.state.eintraege, eintraege);
    expect(cubit.state.laedt, isFalse);
    expect(cubit.state.fehler, isNull);
    expect(protokoll.limits, [50]);
  });

  test('ohne Angabe wird das vereinbarte Limit 200 angefragt', () async {
    final protokoll = VersandTestProtokoll();
    final cubit = GesendetCubit(protokoll);
    addTearDown(cubit.close);

    await cubit.laden();

    expect(protokoll.limits, [200]);
    expect(cubit.state.eintraege, isEmpty);
  });

  test('ein Fehlschlag hinterlaesst eine Meldung, keine halbe Liste', () async {
    final cubit = GesendetCubit(
      VersandTestProtokoll(eintraege: eintraege, fehler: true),
    );
    addTearDown(cubit.close);

    await cubit.laden();

    expect(cubit.state.eintraege, isEmpty);
    expect(cubit.state.laedt, isFalse);
    expect(cubit.state.fehler, contains('erneut versuchen'));
  });

  test('waehrend des Ladens steht laedt, und zwar ohne alte Eintraege', () {
    final cubit = GesendetCubit(VersandTestProtokoll(eintraege: eintraege));
    addTearDown(cubit.close);

    final laeuft = cubit.laden();

    expect(cubit.state.laedt, isTrue);
    expect(cubit.state.fehler, isNull);
    return laeuft;
  });
}
