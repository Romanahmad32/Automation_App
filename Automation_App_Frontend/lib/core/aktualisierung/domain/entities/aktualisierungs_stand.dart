import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/letzte_aktualisierung.dart';
import 'package:equatable/equatable.dart';

/// Der ganze Stand der Aktualisierung aus der App heraus (#196), wie ihn jeder
/// Endpunkt unter `api/Aktualisierung` zurückgibt (`AktualisierungsStandDto`).
///
/// Geprüft, geladen und installiert wird im Dienst, nicht hier: Nur er nutzt
/// System-Proxy und Windows-Zertifikate. Das Frontend fragt nach außen nichts
/// mehr selbst — auch im E2E-Testmodus nicht, dort liefert der Dienst eine
/// Attrappe (`9.9.9`).
class AktualisierungsStand extends Equatable {
  const AktualisierungsStand({
    required this.laufendeVersion,
    required this.zustand,
    this.neueVersion,
    this.geladenBytes = 0,
    this.gesamtBytes,
    this.meldung,
    this.fehlerArt,
    this.downloadUrl,
    this.letzteAktualisierung,
  });

  /// Wie `GET /health` sie meldet.
  final String laufendeVersion;

  /// Dreistellig ohne `v`, sobald eine neuere bekannt ist.
  final String? neueVersion;

  final AktualisierungsZustand zustand;

  /// Fortschritt des Downloads; bei [AktualisierungsZustand.bereit] gleich
  /// [gesamtBytes].
  final int geladenBytes;

  /// Größe der Setup-Datei, sobald eine ladbare bekannt ist.
  final int? gesamtBytes;

  /// Deutsch, für den Anwender — bei `fehler` immer, bei `unbekannt` nach
  /// einer gescheiterten Prüfung.
  final String? meldung;

  /// Nur bei [AktualisierungsZustand.fehler]: welche Ursache der Dialog nennt.
  final AktualisierungsFehlerArt? fehlerArt;

  /// Direkt die Setup-Datei, für „Lieber selbst herunterladen“.
  final String? downloadUrl;

  /// Ergebnis der letzten Aktualisierung, bis es quittiert ist.
  final LetzteAktualisierung? letzteAktualisierung;

  factory AktualisierungsStand.fromJson(Map<String, dynamic> json) {
    final letzte = json['letzteAktualisierung'];
    return AktualisierungsStand(
      laufendeVersion: json['laufendeVersion'] as String? ?? '',
      neueVersion: json['neueVersion'] as String?,
      zustand: AktualisierungsZustand.ausText(json['zustand'] as String?),
      geladenBytes: (json['geladenBytes'] as num?)?.toInt() ?? 0,
      gesamtBytes: (json['gesamtBytes'] as num?)?.toInt(),
      meldung: json['meldung'] as String?,
      fehlerArt: AktualisierungsFehlerArt.ausText(json['fehlerArt'] as String?),
      downloadUrl: json['downloadUrl'] as String?,
      letzteAktualisierung: letzte is Map<String, dynamic>
          ? LetzteAktualisierung.fromJson(letzte)
          : null,
    );
  }

  /// Ob es etwas zu aktualisieren gibt — der Hinweis in der Seitenleiste und
  /// der Knopf in „Über diese Anwendung“ hängen daran. Ein Fehler zählt mit:
  /// Die neue Version ist ja weiter da, nur der Weg dahin hakte.
  bool get updateInSicht =>
      neueVersion != null &&
      const {
        AktualisierungsZustand.verfuegbar,
        AktualisierungsZustand.laedt,
        AktualisierungsZustand.bereit,
        AktualisierungsZustand.fehler,
      }.contains(zustand);

  /// Geladener Anteil zwischen 0 und 1; `null`, solange die Größe fehlt.
  double? get anteil {
    final gesamt = gesamtBytes;
    if (gesamt == null || gesamt <= 0) return null;
    return (geladenBytes / gesamt).clamp(0.0, 1.0);
  }

  /// Abgerundete Prozent — 54 von 92 MB sind 58 %, nicht 59 %: „100 %“ soll
  /// erst dastehen, wenn wirklich alles da ist.
  int? get prozent {
    final wert = anteil;
    return wert == null ? null : (wert * 100).floor();
  }

  /// Derselbe Stand ohne [letzteAktualisierung] — nachdem das Ergebnis
  /// gezeigt und quittiert ist.
  AktualisierungsStand ohneErgebnis() => AktualisierungsStand(
    laufendeVersion: laufendeVersion,
    neueVersion: neueVersion,
    zustand: zustand,
    geladenBytes: geladenBytes,
    gesamtBytes: gesamtBytes,
    meldung: meldung,
    fehlerArt: fehlerArt,
    downloadUrl: downloadUrl,
  );

  @override
  List<Object?> get props => [
    laufendeVersion,
    neueVersion,
    zustand,
    geladenBytes,
    gesamtBytes,
    meldung,
    fehlerArt,
    downloadUrl,
    letzteAktualisierung,
  ];
}
