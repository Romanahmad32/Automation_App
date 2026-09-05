import 'dart:convert';

import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/services/arbeitspaket_bau.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

void main() {
  final geholt = DateTime(2026, 9, 5, 10, 12);

  Arbeitspaket paket(List<String> ordnernamen, {int nummer = 3}) =>
      Arbeitspaket(
        nummer: nummer,
        geholtAm: geholt,
        ordnerAnzahl: ordnernamen.length,
        ordnernamen: ordnernamen,
      );

  final register = [
    mandant(
      1,
      'Schmidt',
      vorname: 'Mark',
      ordner: const ['VUnfallursache Mark Schmidt'],
      kennzeichen: const ['HG-E 1427'],
    ),
  ];

  test('jeder Ordner trägt Aktentyp, Namensvorschlag und Registertreffer', () {
    final gebaut = ArbeitspaketBau.baue(
      paket: paket(const ['VUnfallursache Mark Schmidt']),
      mandanten: register,
      anleitung: 'Anleitung',
    );

    final ordner = (gebaut['ordner'] as List).single as Map<String, dynamic>;
    expect(ordner, {
      'ordnername': 'VUnfallursache Mark Schmidt',
      'aktentyp': 'Verkehrsunfallsache',
      'vorschlagVorname': 'Mark',
      'vorschlagNachname': 'Schmidt',
      'mandantImRegister': 'Mark Schmidt',
    });
  });

  // Der Regelfall im Aktenbestand dieser Kanzlei — und der Fall, um
  // dessentwillen das Paket überhaupt beschriftet wird: Hinter dem Präfix steht
  // nur der Nachname, das Register kennt den Mandanten, also hat der Erzeuger
  // hier nichts zu lesen und hängt den Ordner nur an.
  test('ein einwortiger Ordnername findet den Mandanten im Register', () {
    final gebaut = ArbeitspaketBau.baue(
      paket: paket(const ['VUnfallursache Schmidt']),
      mandanten: register,
      anleitung: 'Anleitung',
    );

    final ordner = (gebaut['ordner'] as List).single as Map<String, dynamic>;
    expect(ordner['vorschlagVorname'], '');
    expect(ordner['vorschlagNachname'], 'Schmidt');
    expect(ordner['mandantImRegister'], 'Mark Schmidt');
  });

  // Der Zweck des Pakets: Wo die App den Mandanten schon kennt, hat der
  // Erzeuger nichts zu lesen. Wo nicht, bleibt das Feld leer statt geraten.
  test('ohne Treffer im Register bleibt der Mandant leer', () {
    final gebaut = ArbeitspaketBau.baue(
      paket: paket(const ['Strafsache Eva Klein']),
      mandanten: register,
      anleitung: 'Anleitung',
    );

    final ordner = (gebaut['ordner'] as List).single as Map<String, dynamic>;
    expect(ordner['aktentyp'], 'Strafsache');
    expect(ordner['vorschlagNachname'], 'Klein');
    expect(ordner['mandantImRegister'], '');
  });

  test('die bekannten Mandanten hängen in Kurzform an', () {
    final gebaut = ArbeitspaketBau.baue(
      paket: paket(const ['VUnfallursache Mark Schmidt']),
      mandanten: register,
      anleitung: 'Anleitung',
    );

    expect(gebaut['bekannteMandanten'], [
      {
        'name': 'Mark Schmidt',
        'ordner': ['VUnfallursache Mark Schmidt'],
        'kennzeichen': ['HG-E 1427'],
      },
    ]);
  });

  // Sie reist in der Datei mit, statt daneben zu liegen: Das Paket wird
  // weitergereicht und in einer späteren Sitzung wieder aufgemacht.
  test('die Anleitung steht in der Datei', () {
    final text = ArbeitspaketBau.alsText(
      paket: paket(const ['VUnfallursache Mark Schmidt']),
      mandanten: register,
      anleitung: ImportAnleitung.paketText,
    );

    final gelesen = jsonDecode(text) as Map<String, dynamic>;
    expect(gelesen['version'], 1);
    expect(gelesen['paket'], 3);
    expect(gelesen['geholtAm'], '2026-09-05T10:12:00.000');
    expect(gelesen['anleitung'], ImportAnleitung.paketText);
    expect(gelesen['anleitung'], contains('GESCHLOSSEN'));
  });

  // Der Ordnername ist das einzige Band zwischen Paket, Antwortdatei und
  // Register. Wer ihn hier putzt, gibt dem Erzeuger einen Namen, den es auf
  // der Platte nicht gibt.
  test('der Ordnername wird unverändert durchgereicht', () {
    const roh = 'vunfallursache  Mark  Schmidt ';
    final gebaut = ArbeitspaketBau.baue(
      paket: paket(const [roh]),
      mandanten: register,
      anleitung: 'Anleitung',
    );

    final ordner = (gebaut['ordner'] as List).single as Map<String, dynamic>;
    expect(ordner['ordnername'], roh);
    expect(
      ordner['aktentyp'],
      'Verkehrsunfallsache',
      reason:
          'Die Erkennung sieht über die Schreibweise hinweg — der Name selbst '
          'bleibt trotzdem, wie er auf der Platte steht.',
    );
  });

  test('der Dateiname trägt die zweistellige Paketnummer', () {
    expect(ArbeitspaketBau.dateiname(paket(const [])), 'arbeitspaket-03.json');
    expect(
      ArbeitspaketBau.dateiname(paket(const [], nummer: 12)),
      'arbeitspaket-12.json',
    );
  });
}
