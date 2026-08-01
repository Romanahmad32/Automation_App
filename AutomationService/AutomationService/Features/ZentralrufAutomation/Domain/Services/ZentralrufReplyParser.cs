using System.Text.RegularExpressions;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Parst den Rohtext einer Zentralruf-Antwortmail (siehe Beispiele/Anwortemail
/// von Zentralruf.txt). Die Mail ist maschinell erzeugt und folgt einem festen
/// Aufbau: Kopf mit "Ihr Zeichen"/"Angefragtes Kennzeichen", danach der Satz
/// "... konnte folgender Versicherer zum Unfalldatum ... ermittelt werden:"
/// gefolgt vom Versicherer-Block (Name, Anschrift, Kontaktdaten, Schein-Nr.).
/// </summary>
public sealed partial class ZentralrufReplyParser : IZentralrufReplyParser
{
    [GeneratedRegex(@"Ihr Zeichen:\s*(.+?)\s*$", RegexOptions.Multiline)]
    private static partial Regex ReferenzRegex();

    [GeneratedRegex(@"Ihre Anfrage(?:\s+mit\s+Zeichen\s+.+?)?\s+vom\s+(\d{2}\.\d{2}\.\d{4})")]
    private static partial Regex AnfrageDatumRegex();

    /// <summary>Beide bekannte Beschriftungen: "Angefragtes" (Blockformat) und "Abgefragtes" (Datenblattformat).</summary>
    [GeneratedRegex(@"A[nb]gefragtes Kennzeichen:\s*(.+?)\s*$", RegexOptions.Multiline)]
    private static partial Regex KennzeichenRegex();

    [GeneratedRegex(@"zum Unfalldatum\s+(\d{2}\.\d{2}\.\d{4})")]
    private static partial Regex UnfallDatumRegex();

    [GeneratedRegex(@"^(\d{5})\s+(.+)$")]
    private static partial Regex PlzOrtRegex();

    /// <summary>Referenzschema "Nr/Jahr Abteilung_Kennzeichen", z. B. "84/26 C03_GG-XY 123".</summary>
    [GeneratedRegex(@"^(\d+)\s*/\s*(\d{2})\s+(\S+)_(.+)$")]
    private static partial Regex ReferenzSchemaRegex();

    /// <summary>
    /// Deutsches Kennzeichen in beliebiger Schreibweise: Unterscheidungszeichen,
    /// Erkennungsbuchstaben, Nummer, optional H/E-Suffix.
    /// </summary>
    [GeneratedRegex(@"^([A-ZÄÖÜ]{1,3})[ \-]?([A-ZÄÖÜ]{1,2})[ \-]?(\d{1,4})\s*([HE])?$")]
    private static partial Regex KennzeichenSchemaRegex();

    /// <summary>Negativ-Antwort: "... konnte kein Versicherer ... ermittelt werden".</summary>
    [GeneratedRegex(@"kein\w*\s+\S*[Vv]ersicherer", RegexOptions.IgnoreCase)]
    private static partial Regex KeinVersichererRegex();

    /// <summary>
    /// Positiver Einleitungssatz des Versicherer-Blocks ("... konnte folgender
    /// Versicherer ... ermittelt werden:"). Bewusst nicht nur "ermittelt werden",
    /// damit Negativ-Antworten ("konnte kein Versicherer ermittelt werden")
    /// nicht fälschlich als Blockanfang gelten.
    /// </summary>
    [GeneratedRegex(@"folgende\w*\s+Versicherer", RegexOptions.IgnoreCase)]
    private static partial Regex VersichererBlockStartRegex();

    public ZentralrufReplyData Parse(string emailText)
    {
        ArgumentNullException.ThrowIfNull(emailText);

        var data = new ZentralrufReplyData
        {
            Referenz = FirstGroup(ReferenzRegex(), emailText),
            AnfrageDatum = FirstGroup(AnfrageDatumRegex(), emailText),
            Kennzeichen = NormalizeKennzeichen(FirstGroup(KennzeichenRegex(), emailText)),
            UnfallDatum = FirstGroup(UnfallDatumRegex(), emailText),
        };

        data = ParseReferenzBestandteile(data);
        data = ParseVersichererBlock(emailText, data);

        // Datenblattformat ("Name der Versicherung: ..."): füllt nur Felder,
        // die der Blockparser leer gelassen hat.
        data = ZentralrufReplyDatenblattFallback.Apply(emailText, data);

        // Negativ-Antwort: nur melden, wenn wirklich kein Versicherer-Block
        // gefunden wurde und der Text das ausdrücklich sagt.
        if (data.VersichererName is null && KeinVersichererRegex().IsMatch(emailText))
        {
            data = data with { KeinVersichererErmittelt = true };
        }

        // Zwischennachricht: keine Auskunft, keine Negativ-Antwort, aber der
        // Text vertröstet auf die manuelle Prüfung / die Folgemail.
        if (data.VersichererName is null
            && !data.KeinVersichererErmittelt
            && ZentralrufZwischennachrichtErkennung.IsZwischennachricht(emailText))
        {
            data = data with { Zwischennachricht = true };
        }

        return data;
    }

    /// <summary>
    /// Zerlegt die Referenz nach dem Schema "Nr/Jahr Abteilung_Kennzeichen"
    /// (siehe REQUIREMENTS.md 3.2), damit die Antwort dem richtigen Vorgang
    /// zugeordnet und gegen das angefragte Kennzeichen geprüft werden kann.
    /// </summary>
    private static ZentralrufReplyData ParseReferenzBestandteile(ZentralrufReplyData data)
    {
        if (data.Referenz is null)
        {
            return data;
        }

        var match = ReferenzSchemaRegex().Match(data.Referenz);
        if (!match.Success)
        {
            return data;
        }

        return data with
        {
            ReferenzAuftragsnummer = match.Groups[1].Value,
            ReferenzJahr = match.Groups[2].Value,
            ReferenzAbteilung = match.Groups[3].Value,
            ReferenzKennzeichen = NormalizeKennzeichen(match.Groups[4].Value),
        };
    }

    /// <summary>
    /// Überführt ein Kennzeichen in die Domänen-Konvention
    /// "Unterscheidungszeichen-Erkennungsbuchstaben Nummer" (z. B. "GG-XY 123").
    /// Nicht erkennbare Schreibweisen bleiben unverändert.
    /// </summary>
    public static string? NormalizeKennzeichen(string? kennzeichen)
    {
        if (string.IsNullOrWhiteSpace(kennzeichen))
        {
            return kennzeichen;
        }

        var match = KennzeichenSchemaRegex().Match(Normalize(kennzeichen).ToUpperInvariant());
        if (!match.Success)
        {
            return Normalize(kennzeichen);
        }

        var suffix = match.Groups[4].Success ? match.Groups[4].Value : string.Empty;
        return $"{match.Groups[1].Value}-{match.Groups[2].Value} {match.Groups[3].Value}{suffix}";
    }

    private static string? FirstGroup(Regex regex, string text)
    {
        var match = regex.Match(text);
        return match.Success ? Normalize(match.Groups[1].Value) : null;
    }

    private static string Normalize(string value) =>
        Regex.Replace(value, @"\s+", " ").Trim();

    /// <summary>
    /// Markiert das Ende des Versicherer-Blocks: der maschinelle Mailtext setzt
    /// danach immer einen dieser Schlusssätze fort.
    /// </summary>
    [GeneratedRegex(@"^\s*(Unseren Auskünften|Eventuelle Rückfragen|Vielen Dank|Mit freundlichen)",
        RegexOptions.IgnoreCase)]
    private static partial Regex VersichererBlockEndeRegex();

    /// <summary>
    /// Liest den zusammenhängenden Block nach "... ermittelt werden:" und ordnet
    /// die Zeilen zu: beschriftete Zeilen
    /// (Tel./Fax/E-Mail/Versicherungsschein-Nr./Versicherungsbeginn), die
    /// PLZ-Ort-Zeile, davor die Straße, alles davor ist der Versicherername.
    ///
    /// Das Blockende wird inhaltlich erkannt (Schlusssatz oder zwei
    /// aufeinanderfolgende Leerzeilen), nicht an der ersten Leerzeile. Aus HTML
    /// gewonnener Text (siehe <see cref="ZentralrufReplyEmailExtractor.HtmlToPlainText"/>)
    /// enthält oft eine Leerzeile zwischen jeder Absatzzeile; bräche der Block
    /// schon dort ab, bliebe nur der Versicherername übrig.
    /// </summary>
    private static ZentralrufReplyData ParseVersichererBlock(string emailText, ZentralrufReplyData data)
    {
        var lines = emailText.Replace("\r\n", "\n").Split('\n');

        var startIndex = Array.FindIndex(
            lines,
            line => VersichererBlockStartRegex().IsMatch(line)
                && line.Contains("ermittelt", StringComparison.OrdinalIgnoreCase));
        if (startIndex < 0)
        {
            return data;
        }

        // Ab dem Einleitungssatz sammeln: Leerzeilen werden übersprungen (eine
        // einzelne trennt im HTML-Text die Absätze), zwei direkt aufeinander
        // folgende oder ein Schlusssatz beenden den Block.
        var blockLines = new List<string>();
        var vorherLeer = false;
        for (var index = startIndex + 1; index < lines.Length; index++)
        {
            var line = lines[index];
            if (string.IsNullOrWhiteSpace(line))
            {
                if (vorherLeer && blockLines.Count > 0)
                {
                    break;
                }
                vorherLeer = true;
                continue;
            }

            if (VersichererBlockEndeRegex().IsMatch(line))
            {
                break;
            }

            vorherLeer = false;
            blockLines.Add(line.Trim());
        }

        var addressLines = new List<string>();
        foreach (var line in blockLines)
        {
            if (TryLabelled(line, "Tel") is { } tel)
            {
                data = data with { VersichererTelefon = tel };
            }
            else if (TryLabelled(line, "Fax") is { } fax)
            {
                data = data with { VersichererFax = fax };
            }
            else if (TryLabelled(line, "E-Mail") is { } email)
            {
                data = data with { VersichererEmail = email };
            }
            else if (TryLabelled(line, "Versicherungsschein-Nr") is { } scheinNr)
            {
                data = data with { VersicherungsscheinNr = scheinNr };
            }
            else if (TryLabelled(line, "Versicherungsbeginn") is { } beginn)
            {
                data = data with { Versicherungsbeginn = beginn };
            }
            else
            {
                addressLines.Add(line);
            }
        }

        var plzOrtIndex = addressLines.FindIndex(line => PlzOrtRegex().IsMatch(line));
        if (plzOrtIndex >= 0)
        {
            var plzOrtMatch = PlzOrtRegex().Match(addressLines[plzOrtIndex]);
            data = data with
            {
                VersichererPlz = plzOrtMatch.Groups[1].Value,
                VersichererOrt = Normalize(plzOrtMatch.Groups[2].Value),
            };

            if (plzOrtIndex >= 1)
            {
                data = data with { VersichererStrasse = Normalize(addressLines[plzOrtIndex - 1]) };
            }
            if (plzOrtIndex >= 2)
            {
                data = data with
                {
                    VersichererName = Normalize(string.Join(' ', addressLines.Take(plzOrtIndex - 1))),
                };
            }
        }
        else if (addressLines.Count > 0)
        {
            // Kein Adressmuster erkannt: alles als Name übernehmen, damit
            // zumindest der Versicherer benannt ist.
            data = data with { VersichererName = Normalize(string.Join(' ', addressLines)) };
        }

        return data;
    }

    /// <summary>Liest "Label: Wert"-Zeilen; toleriert "Tel.:" wie auch "Fax:".</summary>
    private static string? TryLabelled(string line, string label)
    {
        var match = Regex.Match(
            line,
            $@"^{Regex.Escape(label)}\.?\s*:\s*(.+)$",
            RegexOptions.IgnoreCase);
        return match.Success ? Normalize(match.Groups[1].Value) : null;
    }
}
