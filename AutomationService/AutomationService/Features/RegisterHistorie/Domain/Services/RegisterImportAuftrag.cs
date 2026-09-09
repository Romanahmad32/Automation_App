namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Eine Zeile des gewachsenen Registers, wie sie in der Importdatei steht
/// (§6.2). Alle Felder sind Pflicht, aber leer erlaubt: Was in der Freitextzelle
/// nicht auffindbar war, bleibt leer, statt geraten zu werden.
///
/// <c>Spalte1</c> und <c>Aktenzeichen</c> stehen beide darin, obwohl sie
/// dasselbe sagen sollten — genau das ist die billigste Vollständigkeitsprobe
/// des Registers: Stimmen sie nicht überein, ist die Zeile falsch zerlegt.
///
/// <c>Sicherheit</c> ist die Selbsteinschätzung des Erzeugers
/// (<see cref="RegisterSicherheiten"/>), <c>Hinweise</c> sind seine Sätze zu
/// Auffälligkeiten. Beide beschreiben nicht die Akte, sondern den Fund; die
/// Vorschau filtert danach, und bei rund 200 Zeilen je Jahrgang ist das der
/// Unterschied zwischen einer Prüfung und dem Beweis, dass keine stattfand.
/// </summary>
public sealed record ImportRegisterZeile(
    int LaufendeNummer,
    string NummerZusatz,
    string Spalte1,
    string Aktenzeichen,
    string Abteilung,
    string AbteilungRoh,
    string Sachart,
    string Mandant,
    string Gegner,
    string Sachbestand,
    string Unfalldatum,
    string Rechtsgebiet,
    string Freitext,
    string Sicherheit,
    IReadOnlyList<string> Hinweise);

/// <summary>
/// Ein Jahrgang der Datei. Der Jahrgang ist die Einheit, in der übernommen und
/// geprüft wird: Die laufende Nummer läuft je Jahr von 01 aufwärts, also ist
/// „lückenlos" nur innerhalb eines Jahrgangs eine sinnvolle Aussage.
/// </summary>
public sealed record ImportJahrgang(int Jahrgang, IReadOnlyList<ImportRegisterZeile> Zeilen);

/// <summary>
/// Eine gelesene Importdatei plus die Entscheidung, ob nur geprüft oder auch
/// geschrieben wird. Derselbe Auftrag läuft beide Male durch dieselbe Logik —
/// die Vorschau zeigt damit garantiert das, was das Übernehmen tut, und nicht
/// eine zweite Auslegung derselben Regeln.
/// </summary>
public sealed record RegisterImportAuftrag(
    IReadOnlyList<ImportJahrgang> Jahrgaenge,
    bool NurPruefen);
