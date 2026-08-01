import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Löst die Mandanten-Verknüpfung eines Vorgangs gegen die geladene
/// Mandantenliste auf — für die automatische Vorauswahl im Speicherschritt.
/// Liefert null, wenn der Vorgang keinem Registereintrag zugeordnet ist oder
/// der Eintrag nicht (mehr) existiert; dann bleibt die Auswahl manuell.
Mandant? mandantZuVorgang(Vorgang? vorgang, List<Mandant> mandanten) {
  final mandantId = vorgang?.mandantId;
  if (mandantId == null) return null;
  for (final m in mandanten) {
    if (m.id == mandantId) return m;
  }
  return null;
}
