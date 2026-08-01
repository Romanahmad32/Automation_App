using System.Text.RegularExpressions;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Fallback für Zentralruf-Antworten im "Datenblatt"-Format: statt des
/// Fließtext-Blocks ("... konnte folgender Versicherer ... ermittelt werden:")
/// stehen die Werte in beschrifteten Zeilen wie "Name der Versicherung: ...",
/// "Versicherungsscheinnummer / Policennummer: ..." oder "Schadentag: ...".
/// Füllt ausschließlich Felder, die der Hauptparser leer gelassen hat —
/// das bewährte Blockformat (siehe Beispiele/Anwortemail von Zentralruf.txt)
/// behält immer Vorrang.
/// </summary>
public static partial class ZentralrufReplyDatenblattFallback
{
    [GeneratedRegex(@"Name der Versicherung\s*:\s*(.+?)\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex NameRegex();

    [GeneratedRegex(
        @"(?:Versicherungsscheinnummer|Policennummer|Versicherungsschein-?Nr\.?)(?:\s*/\s*Policennummer)?\s*:\s*(.+?)\s*$",
        RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex ScheinNrRegex();

    [GeneratedRegex(@"Anschrift der Versicherung\s*:\s*(.+?)\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex AnschriftRegex();

    [GeneratedRegex(@"Telefonnummer(?:\s*/\s*Kontakt)?\s*:\s*(.+?)\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex TelefonRegex();

    /// <summary>"Schadentag: 09.03.2026" (Datenblatt) wie auch "zum Schadentag 09.03.2026" (Fließtext).</summary>
    [GeneratedRegex(@"Schadentag\s*:?\s*(\d{2}\.\d{2}\.\d{4})", RegexOptions.IgnoreCase)]
    private static partial Regex SchadentagRegex();

    /// <summary>Einzeilige Anschrift "Straße Nr, PLZ Ort" (Komma nach der PLZ toleriert).</summary>
    [GeneratedRegex(@"^(.+?),\s*(\d{5}),?\s+(.+)$")]
    private static partial Regex AnschriftSchemaRegex();

    public static ZentralrufReplyData Apply(string emailText, ZentralrufReplyData data)
    {
        if (data.VersichererName is null && FirstGroup(NameRegex(), emailText) is { } name)
        {
            data = data with { VersichererName = name };
        }

        if (data.VersicherungsscheinNr is null && FirstGroup(ScheinNrRegex(), emailText) is { } scheinNr)
        {
            data = data with { VersicherungsscheinNr = scheinNr };
        }

        if (data.VersichererTelefon is null && FirstGroup(TelefonRegex(), emailText) is { } telefon)
        {
            data = data with { VersichererTelefon = telefon };
        }

        if (data.UnfallDatum is null && FirstGroup(SchadentagRegex(), emailText) is { } schadentag)
        {
            data = data with { UnfallDatum = schadentag };
        }

        if (data.VersichererStrasse is null && FirstGroup(AnschriftRegex(), emailText) is { } anschrift)
        {
            data = ApplyAnschrift(anschrift, data);
        }

        return data;
    }

    private static ZentralrufReplyData ApplyAnschrift(string anschrift, ZentralrufReplyData data)
    {
        var match = AnschriftSchemaRegex().Match(anschrift);
        if (!match.Success)
        {
            // Nicht zerlegbare Anschrift trotzdem übernehmen, damit sie dem
            // Anwalt angezeigt wird und nicht still verloren geht.
            return data with { VersichererStrasse = anschrift };
        }

        data = data with { VersichererStrasse = match.Groups[1].Value.Trim() };
        if (data.VersichererPlz is null)
        {
            data = data with { VersichererPlz = match.Groups[2].Value };
        }
        if (data.VersichererOrt is null)
        {
            data = data with { VersichererOrt = match.Groups[3].Value.Trim() };
        }
        return data;
    }

    private static string? FirstGroup(Regex regex, string text)
    {
        var match = regex.Match(text);
        return match.Success
            ? Regex.Replace(match.Groups[1].Value, @"\s+", " ").Trim()
            : null;
    }
}
