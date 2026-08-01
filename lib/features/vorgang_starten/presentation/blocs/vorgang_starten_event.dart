part of 'vorgang_starten_bloc.dart';

sealed class VorgangStartenEvent {
  const VorgangStartenEvent();
}

/// Lädt die Vorbelegung (laufende Auftragsnummer, Abteilung) aus den
/// Einstellungen, damit das Formular sie anzeigen kann.
final class LadeDefaultsEvent extends VorgangStartenEvent {
  const LadeDefaultsEvent();
}

/// Speichert den Vorgang. Die View hat zuvor (per Dialog) entschieden, was mit
/// dem Mandanten geschieht; genau eines von [neuerMandant]/[aktualisierterMandant]
/// ist gesetzt, oder es wird über [verknuepfteMandantId] nur verknüpft.
final class SpeichereVorgangEvent extends VorgangStartenEvent {
  final VorgangStartenDaten daten;

  /// != null → neuen Mandanten im Register anlegen und verknüpfen.
  final CreateMandantRequest? neuerMandant;

  /// != null → bestehenden Mandanten mit den geänderten Daten aktualisieren.
  final Mandant? aktualisierterMandant;

  /// Bestehende Verknüpfung ohne Änderung; null = kein Register-Mandant.
  final int? verknuepfteMandantId;

  /// Zusätzlich das Zentralruf-Onlineformular im Browser vorbefüllen
  /// (nur bei Verkehrsrecht relevant).
  final bool zentralrufAusfuellen;

  const SpeichereVorgangEvent({
    required this.daten,
    this.neuerMandant,
    this.aktualisierterMandant,
    this.verknuepfteMandantId,
    this.zentralrufAusfuellen = false,
  });
}

/// Speichert nur den Mandanten (ohne Vorgang), ausgelöst über den Button in der
/// Mandanten-Karte. Genau eines von [neuerMandant]/[aktualisierterMandant] ist
/// gesetzt; die View hat die Übersicht bereits bestätigt.
final class SpeichereMandantEvent extends VorgangStartenEvent {
  final CreateMandantRequest? neuerMandant;
  final Mandant? aktualisierterMandant;

  const SpeichereMandantEvent({this.neuerMandant, this.aktualisierterMandant});
}
