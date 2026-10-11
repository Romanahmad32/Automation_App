using System.Text;
using System.Text.RegularExpressions;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Erkennt im Text eines Dokuments, was eine Kanzleivorlage verraet und ein
/// neutrales Muster nie traegt: Bankverbindung und Steuerkennungen -- das, was
/// im Briefkopf der echten Vorlagen steht (.gitignore, Abschnitt Beispiele/).
///
/// Zurueck kommt nur die Art eines Fundes, nie der Wert: Die Protokolle der CI
/// sind oeffentlich, eine Meldung mit dem Wert veroeffentlichte genau ihn. Ein
/// Muster schreibt an diese Stellen Platzhalter ({{IBAN}}), die keine Regel
/// trifft. Wo es eine Pruefziffer gibt, entscheidet sie und nicht die Form
/// allein -- sonst schluege jede Zahlenkolonne einer Schadensaufstellung an.
/// </summary>
public static partial class Kanzleidaten
{
    /// <summary>
    /// Laenge der IBAN je Land, fuer die Laender, aus denen hier Konten zu
    /// erwarten sind. Die Laenge muss stimmen: Ohne sie traefe die Pruefziffer
    /// fast jede hundertste beliebige Zeichenfolge.
    /// </summary>
    static readonly Dictionary<string, int> IbanLaenge = new(StringComparer.Ordinal)
    {
        ["DE"] = 22,
        ["AT"] = 20,
        ["CH"] = 21,
        ["LI"] = 21,
        ["LU"] = 20,
        ["NL"] = 18,
        ["BE"] = 16,
        ["FR"] = 27,
        ["IT"] = 27,
        ["ES"] = 24,
        ["PL"] = 28,
        ["DK"] = 18,
    };

    /// <summary>Die Arten von Kanzleidaten in <paramref name="text"/>, ohne Werte.</summary>
    public static IReadOnlyList<string> Funde(string text)
    {
        var einheitlich = text.Replace(' ', ' ');
        var funde = new List<string>();
        if (IbanAnfang().Matches(einheitlich).Any(treffer => IstIban(einheitlich, treffer.Index)))
        {
            funde.Add("IBAN");
        }

        if (Bic().IsMatch(einheitlich))
        {
            funde.Add("BIC");
        }

        if (Bankleitzahl().IsMatch(einheitlich) || Kontonummer().IsMatch(einheitlich))
        {
            funde.Add("Kontonummer oder BLZ");
        }

        if (UstId().Matches(einheitlich).Any(treffer => UstIdGueltig(treffer.Value)))
        {
            funde.Add("USt-IdNr.");
        }

        if (Steuernummer().Matches(einheitlich).Any(treffer => treffer.Value.Count(char.IsAsciiDigit) >= 10)
            || SteuernummerAmtlich().IsMatch(einheitlich))
        {
            funde.Add("Steuernummer");
        }

        return funde;
    }

    /// <summary>
    /// Ob ab <paramref name="anfang"/> eine IBAN steht: Laenderkennung, genau
    /// so viele Zeichen, wie das Land vorschreibt (Leerzeichen zwischen den
    /// Gruppen zaehlen nicht), Pruefziffer nach ISO 13616 (Rest 1 bei 97).
    /// </summary>
    static bool IstIban(string text, int anfang)
    {
        if (!IbanLaenge.TryGetValue(text.Substring(anfang, 2), out var laenge))
        {
            return false;
        }

        var zeichen = new StringBuilder(laenge);
        for (var i = anfang; i < text.Length && zeichen.Length < laenge; i++)
        {
            if (char.IsAsciiLetterUpper(text[i]) || char.IsAsciiDigit(text[i]))
            {
                zeichen.Append(text[i]);
            }
            else if (text[i] != ' ')
            {
                break;
            }
        }

        if (zeichen.Length < laenge)
        {
            return false;
        }

        var rest = 0;
        foreach (var c in zeichen.ToString(4, laenge - 4) + zeichen.ToString(0, 4))
        {
            rest = char.IsAsciiDigit(c)
                ? (rest * 10 + (c - '0')) % 97
                : (rest * 100 + (c - 'A' + 10)) % 97;
        }

        return rest == 1;
    }

    /// <summary>
    /// Pruefziffer der deutschen USt-IdNr. nach ISO 7064, MOD 11,10 -- das
    /// Verfahren des Bundeszentralamts fuer Steuern.
    /// </summary>
    static bool UstIdGueltig(string treffer)
    {
        var ziffern = treffer.Where(char.IsAsciiDigit).Select(c => c - '0').ToArray();
        var produkt = 10;
        foreach (var ziffer in ziffern[..8])
        {
            var summe = (ziffer + produkt) % 10;
            produkt = 2 * (summe == 0 ? 10 : summe) % 11;
        }

        var pruefziffer = 11 - produkt;
        return (pruefziffer == 10 ? 0 : pruefziffer) == ziffern[8];
    }

    [GeneratedRegex(@"\b[A-Z]{2}\d{2}")]
    private static partial Regex IbanAnfang();

    [GeneratedRegex(@"\b(?:BIC|Bic|SWIFT)(?:-Code)?\s*:?\s*[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\b")]
    private static partial Regex Bic();

    [GeneratedRegex(@"\bBLZ\.?\s*:?\s*\d{3}\s?\d{3}\s?\d{2}\b")]
    private static partial Regex Bankleitzahl();

    [GeneratedRegex(@"\b(?:Konto(?:nummer|-?\s?Nr\.?)?|Kto\.?\s?-?\s?Nr\.?)\s*:?\s*\d{5,10}\b", RegexOptions.IgnoreCase)]
    private static partial Regex Kontonummer();

    [GeneratedRegex(@"\bDE\s?\d{3}\s?\d{3}\s?\d{3}\b")]
    private static partial Regex UstId();

    [GeneratedRegex(@"(?:Steuer\s?-?\s?(?:nummer|Nr\.?)|\bSt\.?\s?-?\s?Nr\.?)\s*:?\s*\d[\d/ ]{8,15}\d", RegexOptions.IgnoreCase)]
    private static partial Regex Steuernummer();

    [GeneratedRegex(@"\b\d{2,3}/\d{3}/\d{4,5}\b")]
    private static partial Regex SteuernummerAmtlich();
}
