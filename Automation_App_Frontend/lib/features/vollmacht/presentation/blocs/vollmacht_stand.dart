import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_auftrag.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Wo der Vollmacht-Dialog gerade steht.
enum VollmachtPhase {
  /// Mandant und Vorlagenstand werden geholt.
  laedt,

  /// Der Anwalt prüft die Kopfdaten.
  eingabe,

  /// Ausfüllen oder Druck läuft.
  arbeitet,

  /// Die Datei ist in Word geöffnet — die App weiß nicht, ob Papier herauskam,
  /// und fragt deshalb, ob sie den Druck vermerken soll.
  inWordGeoeffnet,

  /// Gedruckt oder in Word gedruckt und vermerkt. Der Dialog zeigt, was
  /// passiert ist ([VollmachtStand.abschluss]), bis der Anwalt „Fertig" drückt.
  abgeschlossen,
}

/// Warum die Mandantenfelder gefüllt sind — oder warum nicht.
enum VollmachtMandantLage {
  /// Aus dem Register geholt.
  geladen,

  /// Dem Vorgang ist kein Mandant zugeordnet (`mandantId == null`).
  keinerZugeordnet,

  /// Zugeordnet, aber nicht (mehr) im Register oder nicht abrufbar.
  nichtGefunden,
}

/// Zustand des Vollmacht-Dialogs (§4.11).
class VollmachtStand extends Equatable {
  final VollmachtPhase phase;
  final Vorgang? vorgang;

  /// Die gewählte Vorlagenart; null, solange der Anwalt keine gewählt hat und
  /// sich aus dem Rechtsgebiet keine ableiten ließ.
  final VollmachtArt? art;

  final VollmachtKopfdaten kopfdaten;
  final VollmachtMandantLage mandantLage;

  /// Null, wenn der Stand nicht geladen werden konnte — der Druck bleibt dann
  /// möglich, der Dienst meldet eine fehlende Vorlage selbst.
  final VollmachtVorlagenStand? vorlagen;

  /// Der Standarddrucker; null, solange er nicht abgefragt ist.
  final VollmachtDrucker? drucker;
  final bool druckerLaedt;

  /// Die zuletzt erzeugte Seitenvorschau und der Auftrag, aus dem sie entstand
  /// — daran erkennt der Dialog, ob sie noch zu den Feldern passt.
  final VollmachtVorschau? vorschau;
  final VollmachtAuftrag? vorschauFuer;
  final bool vorschauLaedt;

  /// Zählt jede neue Vorschau — der PDF-Betrachter braucht je Inhalt einen
  /// eigenen Namen, sonst zeigt er die alte Seite weiter.
  final int vorschauNummer;

  /// Die zuletzt ausgefüllte Datei (Phase [VollmachtPhase.inWordGeoeffnet]).
  final String? pfad;

  /// Ob sich [pfad] in Word öffnen ließ.
  final bool geoeffnet;

  /// Platzhalter, die in der Vorlage stehen geblieben sind.
  final List<String> warnungen;

  /// Die Meldung des letzten Schritts, als Rückmeldung zu zeigen — [fehler]
  /// als Fehler, [hinweis] als Hinweis; zusammen mit [meldungsNummer], damit
  /// derselbe Text beim zweiten Mal wieder erscheint.
  final String? fehler;
  final String? hinweis;
  final int meldungsNummer;

  /// Was in Phase [VollmachtPhase.abgeschlossen] stehen bleibt.
  final VollmachtAbschluss? abschluss;

  const VollmachtStand({
    this.phase = VollmachtPhase.laedt,
    this.vorgang,
    this.art,
    this.kopfdaten = VollmachtKopfdaten.leer,
    this.mandantLage = VollmachtMandantLage.geladen,
    this.vorlagen,
    this.drucker,
    this.druckerLaedt = false,
    this.vorschau,
    this.vorschauFuer,
    this.vorschauLaedt = false,
    this.vorschauNummer = 0,
    this.pfad,
    this.geoeffnet = false,
    this.warnungen = const [],
    this.fehler,
    this.hinweis,
    this.meldungsNummer = 0,
    this.abschluss,
  });

  /// Ob die Vorlage zur gewählten Art sicher fehlt.
  bool get vorlageFehlt {
    final gewaehlt = art;
    final stand = vorlagen;
    return gewaehlt != null && stand != null && !stand.hat(gewaehlt);
  }

  /// Ob „Drucken" und „In Word öffnen" greifen dürfen.
  bool get bereit =>
      phase == VollmachtPhase.eingabe && art != null && !vorlageFehlt;

  /// Ob „Drucken" greifen darf — nicht ohne eingerichteten Drucker.
  bool get druckbereit => bereit && (drucker?.kannDrucken ?? true);

  /// Ob der Dialog den Drucker abfragen soll: Die Eingabe steht, und er ist
  /// weder bekannt noch angefragt. Ein gescheiterter Abruf liefert den
  /// Zustand „unbekannt" — gefragt wird also genau einmal.
  bool get druckerFaellig =>
      phase == VollmachtPhase.eingabe && drucker == null && !druckerLaedt;

  /// Ob der Dialog eine erste Vorschau anstoßen soll: Art und Vorlage stehen
  /// fest, und es gibt noch keine. Danach nur noch auf Knopfdruck.
  bool get vorschauFaellig => bereit && vorschau == null && !vorschauLaedt;

  /// Ob die Vorschau eine andere Art oder andere Felder zeigt als eingegeben.
  bool get vorschauVeraltet {
    final fuer = vorschauFuer;
    return vorschau != null &&
        fuer != null &&
        (fuer.art != art || fuer.kopfdaten != kopfdaten);
  }

  VollmachtStand copyWith({
    VollmachtPhase? phase,
    VollmachtArt? art,
    VollmachtKopfdaten? kopfdaten,
    VollmachtMandantLage? mandantLage,
    VollmachtVorlagenStand? vorlagen,
    VollmachtDrucker? drucker,
    bool? druckerLaedt,
    VollmachtVorschau? vorschau,
    VollmachtAuftrag? vorschauFuer,
    bool? vorschauLaedt,
    int? vorschauNummer,
    String? pfad,
    bool? geoeffnet,
    List<String>? warnungen,
    String? fehler,
    String? hinweis,
    ValueGetter<VollmachtAbschluss?>? abschluss,
  }) => VollmachtStand(
    phase: phase ?? this.phase,
    vorgang: vorgang,
    art: art ?? this.art,
    kopfdaten: kopfdaten ?? this.kopfdaten,
    mandantLage: mandantLage ?? this.mandantLage,
    vorlagen: vorlagen ?? this.vorlagen,
    drucker: drucker ?? this.drucker,
    druckerLaedt: druckerLaedt ?? this.druckerLaedt,
    vorschau: vorschau ?? this.vorschau,
    vorschauFuer: vorschauFuer ?? this.vorschauFuer,
    vorschauLaedt: vorschauLaedt ?? this.vorschauLaedt,
    vorschauNummer: vorschauNummer ?? this.vorschauNummer,
    pfad: pfad ?? this.pfad,
    geoeffnet: geoeffnet ?? this.geoeffnet,
    warnungen: warnungen ?? this.warnungen,
    // Eine Meldung gilt nur für den Übergang, der sie bringt.
    fehler: fehler,
    hinweis: hinweis,
    meldungsNummer: fehler == null && hinweis == null
        ? meldungsNummer
        : meldungsNummer + 1,
    abschluss: abschluss != null ? abschluss() : this.abschluss,
  );

  @override
  List<Object?> get props => [
    phase,
    vorgang,
    art,
    kopfdaten,
    mandantLage,
    vorlagen,
    drucker,
    druckerLaedt,
    vorschau,
    vorschauFuer,
    vorschauLaedt,
    vorschauNummer,
    pfad,
    geoeffnet,
    warnungen,
    fehler,
    hinweis,
    meldungsNummer,
    abschluss,
  ];
}
