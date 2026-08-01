/// Ergebnis des Zuordnen-Dialogs: entweder einen neuen Mandanten anlegen oder
/// den Ordner einem bestehenden Mandanten ([mandantId]) zuordnen.
class ZuordnenErgebnis {
  final bool neuerMandant;
  final int? mandantId;

  const ZuordnenErgebnis.neu() : neuerMandant = true, mandantId = null;

  const ZuordnenErgebnis.bestehend(this.mandantId) : neuerMandant = false;
}
