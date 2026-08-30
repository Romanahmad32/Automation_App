import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/referenz_vergeben_exception.dart';

/// Persistenz-Port der vorgaenge-Domäne. Liegt jetzt im Backend (SQLite); die
/// Präsentationsschicht kennt nur diesen Port. Bewusst pro Datensatz
/// (Upsert/Delete) statt Bulk-Replace: jede Änderung schreibt genau einen
/// Vorgang, damit auch bei tausenden (inkl. abgeschlossener) schnell gespeichert
/// wird.
abstract class VorgangRepository {
  /// Lädt die persistierten Vorgänge.
  Future<List<Vorgang>> loadVorgaenge();

  /// Legt den Vorgang an oder ersetzt den bestehenden mit gleicher Referenz.
  /// Liefert den gespeicherten Stand zurück.
  Future<Vorgang> upsertVorgang(Vorgang vorgang);

  /// Löscht den Vorgang zur Referenz (No-op, wenn keiner passt).
  Future<void> deleteVorgang(String referenz);

  /// Hinterlegt den angefangenen Ausfüllstand am Vorgang — [entwurf] `null`
  /// verwirft ihn. Eigener Weg statt [upsertVorgang]: Der Entwurf wird beim
  /// Tippen laufend geschrieben, und ein Upsert schickte dabei jedes Mal den
  /// ganzen Vorgang aus der Sicht des Clients mit. Käme währenddessen eine
  /// Zentralruf-Antwort herein, wäre sie danach überschrieben.
  ///
  /// Liefert den gespeicherten Stand; null, wenn kein Vorgang zur Referenz
  /// existiert.
  Future<Vorgang?> setzeEntwurf(String referenz, VorgangEntwurf? entwurf);

  /// Schließt den Vorgang zur Referenz atomar im Backend ab (§4.8):
  /// Status „versendet" und Hochzählen der laufenden Auftragsnummer passieren
  /// dort in einer Transaktion. Liefert den abgeschlossenen Stand zurück,
  /// null, wenn kein Vorgang zur Referenz existiert.
  Future<Vorgang?> abschliessenVorgang(String referenz);

  /// Benennt den Vorgang von [von] auf [nach] um (Referenz korrigieren,
  /// z. B. Tippfehler im Kennzeichen). Die Referenz ist der fachliche
  /// Schlüssel — ein Upsert unter der neuen Referenz würde ein Duplikat
  /// anlegen, deshalb dieser eigene Backend-Schritt. Liefert den umbenannten
  /// Stand (mit neu abgeleiteten Referenz-Bestandteilen) zurück; null, wenn
  /// kein Vorgang zu [von] existiert. Wirft [ReferenzVergebenException],
  /// wenn [nach] bereits einem anderen Vorgang gehört.
  Future<Vorgang?> aendereReferenz(String von, String nach);
}
