namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Ein Mandant, wie er in der Importdatei steht. Alles außer dem Namen ist
/// freiwillig — die Datei entsteht maschinell aus dem Aktenbestand, und was
/// dort nicht auffindbar war, bleibt leer statt geraten zu werden.
///
/// Zwei Felder beschreiben nicht den Mandanten, sondern den Fund:
/// <c>Quelle</c> nennt frei, woher die Angaben stammen (Datei- oder
/// Ordnerpfad), und <c>Sicherheit</c> ist die Selbsteinschätzung des Erzeugers
/// (<c>hoch</c>, <c>mittel</c>, <c>niedrig</c>). Die Vorschau filtert danach —
/// bei tausenden Zeilen ist das der Unterschied zwischen einer prüfbaren und
/// einer blind übernommenen Übernahme.
/// </summary>
public sealed record ImportMandant(
    string Anrede,
    string Vorname,
    string Nachname,
    string StrasseHausnummer,
    string Postleitzahl,
    string Ort,
    string EmailAdresse,
    string Telefonnummer,
    string Notiz,
    IReadOnlyList<string> AktenOrdnernamen,
    IReadOnlyList<string> Kennzeichen,
    string Quelle,
    string Sicherheit);

/// <summary>
/// Eine gelesene Importdatei plus die Entscheidung, ob nur geprüft oder auch
/// geschrieben wird. Derselbe Auftrag läuft beide Male durch — die Vorschau
/// zeigt damit garantiert das, was das Übernehmen tut, und nicht eine zweite
/// Auslegung derselben Regeln.
/// </summary>
public sealed record MandantenImportAuftrag(
    IReadOnlyList<ImportMandant> Mandanten,
    IReadOnlyList<string> OhneMandantenbezug,
    bool NurPruefen);
