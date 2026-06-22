part of 'zentralruf_bloc.dart';

sealed class ZentralrufEvent {
  const ZentralrufEvent();
}

/// Lädt die Vorbelegung (laufende Auftragsnummer, Abteilung) aus den
/// Einstellungen, damit das Formular sie anzeigen kann.
final class LoadZentralrufDefaultsEvent extends ZentralrufEvent {
  const LoadZentralrufDefaultsEvent();
}

final class PrefillZentralrufFormEvent extends ZentralrufEvent {
  final ZentralrufRequest request;

  /// Verknüpfung des angelegten Vorgangs mit einem Mandanten aus dem Register
  /// (null, wenn der Geschädigte nicht aus dem Register gewählt wurde).
  final int? mandantId;

  /// Schnappschuss des Mandanten-/Geschädigtennamens für Anzeige und
  /// Sachgebiete-Register (auch ohne Registereintrag aus dem Formular gefüllt).
  final String? mandantName;

  /// Rechtsgebiet des Vorgangs (Standard: Verkehrsrecht).
  final Rechtsgebiet rechtsgebiet;

  const PrefillZentralrufFormEvent({
    required this.request,
    this.mandantId,
    this.mandantName,
    this.rechtsgebiet = Rechtsgebiet.verkehrsrecht,
  });
}
