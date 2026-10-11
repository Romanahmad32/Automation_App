import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_feld.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_feldauswahl.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Welche Kopffelder der Vollmacht-Dialog zeigt und welche auf dem Papier
/// frei bleiben (§4.11, #171).
void main() {
  VollmachtVorlage vorlage(List<String>? platzhalter) => VollmachtVorlage(
    art: VollmachtArt.unfallsachen,
    dateiname: 'Vollmacht Unfallsachen.docx',
    vorhanden: true,
    platzhalter: platzhalter,
  );

  Set<VollmachtFeld> sichtbar(
    List<String>? platzhalter, {
    VollmachtArt art = VollmachtArt.strafsache,
  }) => VollmachtFeldauswahl.sichtbar(art, vorlage(platzhalter));

  const mandantenfelder = {
    VollmachtFeld.vorname,
    VollmachtFeld.nachname,
    VollmachtFeld.strasse,
    VollmachtFeld.plz,
    VollmachtFeld.ort,
    VollmachtFeld.telefon,
    VollmachtFeld.email,
  };

  group('Zuordnung Feld → Platzhalter', () {
    for (final (platzhalter, felder) in [
      ('MandantVorname', {VollmachtFeld.vorname}),
      ('MandantNachname', {VollmachtFeld.nachname}),
      ('MandantName', {VollmachtFeld.vorname, VollmachtFeld.nachname}),
      ('MandantStrasse', {VollmachtFeld.strasse}),
      ('MandantPlz', {VollmachtFeld.plz}),
      ('MandantOrt', {VollmachtFeld.ort}),
      (
        'MandantAnschrift',
        {VollmachtFeld.strasse, VollmachtFeld.plz, VollmachtFeld.ort},
      ),
      ('MandantTelefon', {VollmachtFeld.telefon}),
      ('MandantEmail', {VollmachtFeld.email}),
      ('InSachen', {VollmachtFeld.inSachen}),
      ('Wegen', {VollmachtFeld.wegen}),
    ]) {
      test('$platzhalter zeigt ${felder.map((f) => f.name).join(', ')}', () {
        expect(sichtbar([platzhalter]), felder);
      });
    }

    test('Groß-/Kleinschreibung zählt nicht', () {
      expect(sichtbar(['mandantvorname', 'WEGEN']), {
        VollmachtFeld.vorname,
        VollmachtFeld.wegen,
      });
    });

    test('Unfalldatum nur bei Unfallsachen, und nur mit „wegen"', () {
      expect(sichtbar(['Wegen'], art: VollmachtArt.unfallsachen), {
        VollmachtFeld.unfalldatum,
        VollmachtFeld.wegen,
      });
      expect(sichtbar(['MandantVorname'], art: VollmachtArt.unfallsachen), {
        VollmachtFeld.vorname,
      });
    });

    test('Unfalldatum auch mit eigenem Platzhalter, ohne „wegen"', () {
      // Der Dienst setzt {{Unfalldatum}} ein, leer als Linie — eine Vorlage
      // damit braucht das Feld, auch wenn sie „wegen" nicht führt.
      expect(sichtbar(['Unfalldatum'], art: VollmachtArt.unfallsachen), {
        VollmachtFeld.unfalldatum,
      });
      expect(sichtbar(['Unfalldatum']), isEmpty);
    });

    test('Tatdatum nur bei Bußgeldsachen, und nur mit „wegen"', () {
      expect(sichtbar(['Wegen'], art: VollmachtArt.bussgeldsachen), {
        VollmachtFeld.tatdatum,
        VollmachtFeld.wegen,
      });
      expect(sichtbar(['Wegen']), {VollmachtFeld.wegen});
    });

    test('eine Vorlage ohne Platzhalter zeigt keine Felder', () {
      expect(sichtbar(const []), isEmpty);
    });
  });

  group('die heutigen Kanzleivorlagen', () {
    final stand = VollmachtRepositoryDouble.standMit(
      VollmachtArt.values.toSet(),
      platzhalter: VollmachtRepositoryDouble.heutigePlatzhalter,
    );
    Set<VollmachtFeld> zu(VollmachtArt art) =>
        VollmachtFeldauswahl.sichtbar(art, stand.zu(art));

    test('Telefon und E-Mail nur bei Unfallsachen', () {
      expect(zu(VollmachtArt.unfallsachen), containsAll(mandantenfelder));
      for (final art in [
        VollmachtArt.bussgeldsachen,
        VollmachtArt.strafsache,
      ]) {
        expect(zu(art), isNot(contains(VollmachtFeld.telefon)));
        expect(zu(art), isNot(contains(VollmachtFeld.email)));
      }
    });

    test('jede Art zeigt ihr Datum, keine das der anderen', () {
      expect(
        zu(VollmachtArt.unfallsachen),
        contains(VollmachtFeld.unfalldatum),
      );
      expect(
        zu(VollmachtArt.unfallsachen),
        isNot(contains(VollmachtFeld.tatdatum)),
      );
      expect(zu(VollmachtArt.bussgeldsachen), contains(VollmachtFeld.tatdatum));
      expect(
        zu(VollmachtArt.strafsache)
            .intersection({VollmachtFeld.unfalldatum, VollmachtFeld.tatdatum}),
        isEmpty,
      );
    });
  });

  group('Vorlage unbekannt → alle Felder wie bisher', () {
    test('platzhalter == null', () {
      expect(sichtbar(null), {
        ...mandantenfelder,
        VollmachtFeld.inSachen,
        VollmachtFeld.wegen,
      });
    });

    test('kein Vorlagenstand', () {
      expect(VollmachtFeldauswahl.sichtbar(VollmachtArt.unfallsachen, null), {
        ...mandantenfelder,
        VollmachtFeld.unfalldatum,
        VollmachtFeld.inSachen,
        VollmachtFeld.wegen,
      });
    });

    test('keine Art gewählt: alle bis auf die Daten', () {
      expect(VollmachtFeldauswahl.sichtbar(null, null), {
        ...mandantenfelder,
        VollmachtFeld.inSachen,
        VollmachtFeld.wegen,
      });
    });
  });

  group('frei bleibend', () {
    test('leere Mandantenfelder, in Formularreihenfolge', () {
      const kopf = VollmachtKopfdaten(
        nachname: 'Probe',
        plz: '12345',
        ort: 'Musterstadt',
        telefon: '  ',
        email: 'max@example.org',
        inSachen: '',
        wegen: '',
      );
      expect(
        VollmachtFeldauswahl.freiBleibend(VollmachtArt.strafsache, null, kopf),
        [VollmachtFeld.vorname, VollmachtFeld.strasse, VollmachtFeld.telefon],
        reason: 'Nur Leerzeichen ist leer; „in Sachen" und „wegen" nie.',
      );
    });

    test('nur, was die Vorlage auch druckt', () {
      const kopf = VollmachtKopfdaten(vorname: 'Max', nachname: 'Probe');
      expect(
        VollmachtFeldauswahl.freiBleibend(
          VollmachtArt.strafsache,
          vorlage(['MandantName', 'MandantAnschrift']),
          kopf,
        ),
        [VollmachtFeld.strasse, VollmachtFeld.plz, VollmachtFeld.ort],
      );
    });

    test('ein leeres Datum nur, solange „wegen" die Vorbelegung ist', () {
      const art = VollmachtArt.bussgeldsachen;
      const leer = VollmachtKopfdaten(vorname: 'Max', nachname: 'Probe');
      final vorbelegt = leer.copyWith(
        wegen: VollmachtVorbelegung.wegen(art, leer),
      );
      final eigen = vorbelegt.copyWith(wegen: 'Vorwurf der OWi. vom Mai');
      final mitDatum = vorbelegt.copyWith(tatdatum: '03.10.2026');

      bool frei(VollmachtKopfdaten kopf) =>
          VollmachtFeldauswahl.bleibtFrei(VollmachtFeld.tatdatum, art, kopf);
      expect(frei(vorbelegt), isTrue);
      expect(frei(eigen), isFalse, reason: 'Das Datum speist nichts mehr.');
      expect(frei(mitDatum), isFalse);
    });

    test('ein leeres Unfalldatum mit eigenem Platzhalter auch bei eigenem '
        '„wegen"', () {
      // Der Dienst setzt {{Unfalldatum}} leer als Linie ein — gleich, was in
      // „wegen" steht.
      const art = VollmachtArt.unfallsachen;
      const kopf = VollmachtKopfdaten(wegen: 'Schadensersatz, von Hand');

      bool frei(List<String>? platzhalter) => VollmachtFeldauswahl.bleibtFrei(
        VollmachtFeld.unfalldatum,
        art,
        kopf,
        vorlage: vorlage(platzhalter),
      );
      expect(frei(['Wegen', 'unfalldatum']), isTrue);
      expect(frei(['Wegen']), isFalse);
      expect(frei(null), isFalse);
    });
  });

  group('Vertrag: platzhalter in GET api/Vollmacht/vorlagen', () {
    VollmachtVorlage lies(Map<String, dynamic> zusatz) =>
        VollmachtVorlage.fromJson({
          'art': 'unfallsachen',
          'dateiname': 'Vollmacht Unfallsachen.docx',
          'vorhanden': true,
          ...zusatz,
        });

    test('eine Liste wird übernommen, Fremdes darin übergangen', () {
      expect(
        lies({
          'platzhalter': ['MandantVorname', 3, 'Wegen'],
        }).platzhalter,
        ['MandantVorname', 'Wegen'],
      );
    });

    test('null oder fehlend heißt unbekannt, [] heißt keine', () {
      expect(lies({'platzhalter': null}).platzhalter, isNull);
      expect(lies({}).platzhalter, isNull);
      expect(lies({'platzhalter': <String>[]}).platzhalter, isEmpty);
    });
  });
}
