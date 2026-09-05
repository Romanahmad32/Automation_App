import 'dart:convert';

import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/ordnername_vorschlag.dart';

/// Baut aus einem [Arbeitspaket] (nur Ordnernamen) und dem Mandantenregister
/// die Datei, die der Erzeuger als **Eingabe** bekommt.
///
/// Der Zweck ist, dem Erzeuger das Lesen abzunehmen: Zu jedem Ordner steht
/// schon in der Datei, was die App ohnehin weiß — der Aktentyp aus dem Präfix,
/// der Namensvorschlag aus dem Ordnernamen und, wenn erkannt, der passende
/// Mandant im Register. Für einen großen Teil der Ordner bleibt damit nichts
/// zu lesen: Ordner anhängen, fertig. Gelesen wird nur, wo etwas fehlt.
///
/// Diese drei Auskünfte kommen aus [AktentypErkennung], [nameVorschlagAusOrdner]
/// und [MandantErkennung] — denselben Diensten, die auch der Zuordnungsstapel
/// und das Formular benutzen. Eine zweite Fassung davon (etwa im Backend) liefe
/// beim ersten gefundenen Schreibfehler auseinander, und dann sagte das Paket
/// etwas anderes als die Oberfläche.
///
/// **Die Anleitung reist in der Datei mit**, statt daneben zu liegen: Das Paket
/// wird weitergereicht, an einen Agenten übergeben, in einer späteren Sitzung
/// wieder aufgemacht. Eine Anleitung, die man dazulegen muss, ist genau die,
/// die beim dritten Paket fehlt.
class ArbeitspaketBau {
  const ArbeitspaketBau._();

  /// Fassung des **Paket**formats. Die Antwortdatei bleibt davon unberührt —
  /// sie ist weiter Fassung 1 nach `docs/MANDANTEN_IMPORT.md`.
  static const int paketVersion = 1;

  /// Der Inhalt der Paketdatei als JSON-Baum.
  static Map<String, dynamic> baue({
    required Arbeitspaket paket,
    required List<Mandant> mandanten,
    required String anleitung,
  }) => {
    'version': paketVersion,
    'anleitung': anleitung,
    'paket': paket.nummer,
    'geholtAm': paket.geholtAm.toIso8601String(),
    'ordner': [
      for (final ordnername in paket.ordnernamen)
        _ordner(ordnername, mandanten),
    ],
    'bekannteMandanten': [for (final m in mandanten) _bekannt(m)],
  };

  /// Derselbe Inhalt als Text, wie er auf die Platte geht: eingerückt, damit
  /// ein Mensch hineinsehen kann, ohne ihn erst durch ein Werkzeug zu schicken.
  static String alsText({
    required Arbeitspaket paket,
    required List<Mandant> mandanten,
    required String anleitung,
  }) => const JsonEncoder.withIndent(
    '  ',
  ).convert(baue(paket: paket, mandanten: mandanten, anleitung: anleitung));

  /// Dateiname mit zweistelliger Paketnummer — so stehen die Pakete im
  /// Explorer in der Reihenfolge, in der sie geholt wurden.
  static String dateiname(Arbeitspaket paket) =>
      'arbeitspaket-${paket.nummer.toString().padLeft(2, '0')}.json';

  /// Ein Ordner mit allem, was die App über ihn weiß.
  ///
  /// Der **Ordnername geht unverändert durch** — er ist das einzige Band
  /// zwischen Paket, Antwortdatei und Register. Ihn hier zu putzen (trimmen,
  /// Groß-/Kleinschreibung vereinheitlichen) hieße, dem Erzeuger einen Namen zu
  /// geben, den es auf der Platte nicht gibt.
  static Map<String, dynamic> _ordner(
    String ordnername,
    List<Mandant> mandanten,
  ) {
    final vorschlag = nameVorschlagAusOrdner(ordnername);
    final treffer = MandantErkennung.finde(
      mandanten: mandanten,
      vorname: vorschlag.vorname,
      nachname: vorschlag.nachname,
    );
    return {
      'ordnername': ordnername,
      'aktentyp': AktentypErkennung.typVon(ordnername).bezeichnung,
      'vorschlagVorname': vorschlag.vorname,
      'vorschlagNachname': vorschlag.nachname,
      // Der Anzeigename, nicht die ID: Schlüssel vergibt die Datenbank, und der
      // Erzeuger hängt seine Zeile ohnehin über den Namen an — genauso, wie der
      // Import sie später wiederfindet.
      'mandantImRegister': treffer.isEmpty
          ? ''
          : treffer.first.mandant.anzeigename,
    };
  }

  /// Ein bekannter Mandant in Kurzform. Mehr braucht der Erzeuger nicht, um
  /// einen Ordner an einen vorhandenen Eintrag zu hängen statt einen zweiten
  /// anzulegen — und weniger personenbezogene Daten verlassen die App.
  static Map<String, dynamic> _bekannt(Mandant mandant) => {
    'name': mandant.anzeigename,
    'ordner': mandant.aktenOrdnernamen,
    'kennzeichen': mandant.kennzeichen,
  };
}
