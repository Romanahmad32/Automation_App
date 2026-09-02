namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Der <b>Anfang</b> einer Anrede in seinen drei Beugungsformen (§4.7, §7.1) —
/// einer der Anreden, aus denen der Anwalt beim Verfassen wählt.
///
/// Bewusst nur der Anfang: Anredewort und Nachname hängt der Versand an
/// (<c>Herr</c>/<c>Frau</c> aus <c>MandantEntity.Anrede</c>, der Name aus dem
/// Register). Ein Baustein, der die ganze Zeile trüge, müsste den Nachnamen
/// kennen — und stünde damit für genau einen Mandanten.
///
/// Drei Formen und nicht eine, weil das Deutsche hier beugt: „Sehr
/// geehrt<b>er</b> Herr" gegen „Sehr geehrt<b>e</b> Frau". Eine Form für alle
/// hieße, jede zweite Mail falsch anzureden. <see cref="Neutral"/> gilt, wenn
/// das Geschlecht nicht hinterlegt ist oder neben dem Mandanten noch jemand
/// mitliest — dort folgt „Damen und Herren" statt eines Namens.
/// </summary>
public class AnredeBausteinEntity
{
    public int Id { get; set; }

    /// <summary>Anfang für einen männlichen Mandanten, z. B. „Sehr geehrter".</summary>
    public string Maennlich { get; set; } = string.Empty;

    /// <summary>Anfang für eine weibliche Mandantin, z. B. „Sehr geehrte".</summary>
    public string Weiblich { get; set; } = string.Empty;

    /// <summary>
    /// Anfang ohne Geschlechtsbezug, z. B. „Sehr geehrte" — davor steht dann
    /// „Damen und Herren" statt Herr/Frau und Nachname.
    /// </summary>
    public string Neutral { get; set; } = string.Empty;

    /// <summary>
    /// Reihenfolge in der Auswahl. Zehnerschritte, damit sich später etwas
    /// dazwischen einsortieren lässt, ohne die ganze Liste umzunummerieren.
    /// </summary>
    public int Sortierung { get; set; }
}
