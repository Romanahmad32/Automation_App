import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:equatable/equatable.dart';

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

  /// Fertig; der Dialog schließt sich mit [VollmachtStand.abschluss].
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

  /// Die zuletzt ausgefüllte Datei (Phase [VollmachtPhase.inWordGeoeffnet]).
  final String? pfad;

  /// Ob sich [pfad] in Word öffnen ließ.
  final bool geoeffnet;

  /// Platzhalter, die in der Vorlage stehen geblieben sind.
  final List<String> warnungen;

  /// Die Meldung des letzten Schritts, als Rückmeldung zu zeigen; zusammen mit
  /// [meldungsNummer], damit derselbe Text beim zweiten Mal wieder erscheint.
  final String? fehler;
  final int meldungsNummer;

  /// Text der Rückmeldung beim Schließen, und ob alles geklappt hat.
  final String? abschluss;
  final bool abschlussOhneMakel;

  const VollmachtStand({
    this.phase = VollmachtPhase.laedt,
    this.vorgang,
    this.art,
    this.kopfdaten = VollmachtKopfdaten.leer,
    this.mandantLage = VollmachtMandantLage.geladen,
    this.vorlagen,
    this.pfad,
    this.geoeffnet = false,
    this.warnungen = const [],
    this.fehler,
    this.meldungsNummer = 0,
    this.abschluss,
    this.abschlussOhneMakel = true,
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

  VollmachtStand copyWith({
    VollmachtPhase? phase,
    VollmachtArt? art,
    VollmachtKopfdaten? kopfdaten,
    VollmachtMandantLage? mandantLage,
    VollmachtVorlagenStand? vorlagen,
    String? pfad,
    bool? geoeffnet,
    List<String>? warnungen,
    String? fehler,
    String? abschluss,
    bool? abschlussOhneMakel,
  }) => VollmachtStand(
    phase: phase ?? this.phase,
    vorgang: vorgang,
    art: art ?? this.art,
    kopfdaten: kopfdaten ?? this.kopfdaten,
    mandantLage: mandantLage ?? this.mandantLage,
    vorlagen: vorlagen ?? this.vorlagen,
    pfad: pfad ?? this.pfad,
    geoeffnet: geoeffnet ?? this.geoeffnet,
    warnungen: warnungen ?? this.warnungen,
    // Eine Meldung gilt nur für den Übergang, der sie bringt.
    fehler: fehler,
    meldungsNummer: fehler == null ? meldungsNummer : meldungsNummer + 1,
    abschluss: abschluss ?? this.abschluss,
    abschlussOhneMakel: abschlussOhneMakel ?? this.abschlussOhneMakel,
  );

  @override
  List<Object?> get props => [
    phase,
    vorgang,
    art,
    kopfdaten,
    mandantLage,
    vorlagen,
    pfad,
    geoeffnet,
    warnungen,
    fehler,
    meldungsNummer,
    abschluss,
    abschlussOhneMakel,
  ];
}
