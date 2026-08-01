using System.Text.RegularExpressions;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Erkennt Zwischennachrichten des Zentralrufs: Mails, die keine Auskunft
/// enthalten, sondern mitteilen, dass die Anfrage nicht sofort beantwortet
/// werden konnte (manuelle Prüfung durch die Fachabteilung, ausländisches
/// Kennzeichen / Grüne-Karte-Fall). Laut Zentralruf-FAQ erfolgt die Auskunft
/// dann in der Regel innerhalb von 24 Stunden per Folgemail.
/// Nur anwenden, wenn weder Versicherer noch Negativ-Auskunft gefunden wurden.
/// </summary>
public static partial class ZentralrufZwischennachrichtErkennung
{
    /// <summary>
    /// Formulierungen, die eine Zwischennachricht kennzeichnen. Bewusst nur
    /// starke Signale, damit gewöhnliche Antworten oder fremde Mails nicht
    /// fälschlich als Zwischennachricht gelten.
    /// </summary>
    [GeneratedRegex(
        @"Zwischennachricht" +
        @"|nicht\s+sofort\s+(?:möglich|erteilt|beantwortet)" +
        @"|(?:zur\s+manuellen\s+(?:Überprüfung|Prüfung|Bearbeitung)|an\s+die\s+(?:zuständige\s+)?Fachabteilung)" +
        @"|sobald\s+(?:uns\s+)?das\s+Ergebnis\s+vorliegt" +
        @"|melden\s+uns\s+unaufgefordert" +
        @"|(?:zuständige[sn]?\s+(?:deutsche[sn]?\s+)?Regulierungsbüro|Grüne[n]?\s+Karte)",
        RegexOptions.IgnoreCase)]
    private static partial Regex ZwischennachrichtRegex();

    public static bool IsZwischennachricht(string emailText) =>
        ZwischennachrichtRegex().IsMatch(emailText);
}
