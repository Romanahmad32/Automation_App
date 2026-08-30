using System.Globalization;
using System.Xml.Linq;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Baut die Schadensaufstellung als Word-Tabelle und setzt sie an die Stelle des
/// Platzhalters {{Schadensaufstellung}}.
///
/// Layout wie die bisher manuell eingebettete Excel-Aufstellung der Kanzlei:
/// Position | Bezeichnung | Forderung in €, Positionszeilen mit Zebra-Streifen,
/// Leerzeile, Zwischensumme (dick umrandet) und RA-Kosten — horizontal zentriert.
/// (Das Excel-OLE-Objekt selbst kann DocX nicht befüllen: Word zeigt davon nur
/// ein gecachtes Bild, das bei programmatischen Änderungen veraltet bliebe.)
/// </summary>
public static class DamageListingTable
{
    public const string Placeholder = "{{Schadensaufstellung}}";

    // Standardfarbe wie im Excel-Vorbild der Kanzlei (eingebettete Tabelle in
    // "VORLAGE Fahrspurwechsel mit Auflistung"): grauer Kopf, dezente Zebra-Streifen.
    private const string DefaultHeaderColorHex = "D9D9D9";

    /// <summary>
    /// Ersetzt den Platzhalter-Absatz durch die Tabelle und stellt die
    /// RVG-Kostenkalkulation als zusätzliche Platzhalterwerte bereit.
    /// </summary>
    /// <exception cref="TemplateProcessingException">
    /// Die Vorlage hat keinen Platzhalter für die Aufstellung — dann ist die
    /// falsche Vorlage gewählt (eine "ohne Auflistung").
    /// </exception>
    public static void Insert(DocX document, DamageListing listing, Dictionary<string, string> replacementValues)
    {
        ArgumentNullException.ThrowIfNull(document);
        ArgumentNullException.ThrowIfNull(listing);
        ArgumentNullException.ThrowIfNull(replacementValues);

        var culture = CultureInfo.GetCultureInfo("de-DE");
        var gegenstandswert = listing.Items.Sum(item => item.Amount);
        var calculation = RvgFeeCalculator.Calculate(
            gegenstandswert,
            listing.Gebuehrensatz,
            listing.ApplyVat,
            listing.GeschaeftsgebuehrOverride,
            listing.AuslagenpauschaleOverride);

        replacementValues["Gegenstandswert"] = calculation.Gegenstandswert.ToString("N2", culture);
        replacementValues["Gebuehrensatz"] = calculation.Gebuehrensatz.ToString("0.0#", culture);
        replacementValues["Geschaeftsgebuehr"] = calculation.Geschaeftsgebuehr.ToString("N2", culture);
        replacementValues["Auslagenpauschale"] = calculation.Auslagenpauschale.ToString("N2", culture);
        replacementValues["RvgNetto"] = calculation.Netto.ToString("N2", culture);
        replacementValues["RvgUmsatzsteuer"] = calculation.Umsatzsteuer.ToString("N2", culture);
        replacementValues["RvgBrutto"] = calculation.Brutto.ToString("N2", culture);

        var markerParagraph = document.Paragraphs.FirstOrDefault(paragraph =>
            paragraph.Text.Contains(Placeholder, StringComparison.OrdinalIgnoreCase));
        if (markerParagraph is null)
        {
            throw new TemplateProcessingException(
                $"Die Vorlage enthält keinen Platzhalter {Placeholder}. " +
                "Für eine Schadensaufstellung muss eine Vorlage mit Auflistung verwendet werden.");
        }

        // Schrift des Marker-Absatzes übernehmen, damit die Tabelle nicht in der
        // Dokument-Standardschrift (z. B. Times New Roman) erscheint.
        var markerFormatting = markerParagraph.MagicText
            .Select(magicText => magicText.formatting)
            .FirstOrDefault(formatting => formatting is not null);

        var table = Build(document, listing, calculation, markerFormatting, culture);

        markerParagraph.InsertTableBeforeSelf(table);
        markerParagraph.Remove(false);
    }

    /// <summary>Parst "RRGGBB" (optional mit führendem '#') in die Kopfzeilen-Farbe.</summary>
    private static (byte R, byte G, byte B) ParseHeaderColor(string? headerColorHex)
    {
        var hex = string.IsNullOrWhiteSpace(headerColorHex)
            ? DefaultHeaderColorHex
            : headerColorHex.TrimStart('#');
        return (
            Convert.ToByte(hex[..2], 16),
            Convert.ToByte(hex[2..4], 16),
            Convert.ToByte(hex[4..6], 16));
    }

    /// <summary>
    /// Zebra-Streifen passend zur Kopfzeile: dieselbe Farbe, kräftig Richtung Weiß
    /// aufgehellt (beim Standardgrau D9D9D9 ergibt das das bisherige F2F2F2).
    /// </summary>
    private static (byte R, byte G, byte B) LightenForBandedRows((byte R, byte G, byte B) color)
    {
        byte Lighten(byte channel) => (byte)Math.Min(255, channel + (255 - channel) * 0.66m);
        return (Lighten(color.R), Lighten(color.G), Lighten(color.B));
    }

    private static Table Build(
        DocX document,
        DamageListing listing,
        RvgCalculation calculation,
        Formatting? markerFormatting,
        CultureInfo culture)
    {
        var headerColor = ParseHeaderColor(listing.HeaderColorHex);
        var bandedColor = LightenForBandedRows(headerColor);
        var headerShading = new ShadingPattern
        {
            Fill = Xceed.Drawing.Color.Parse(headerColor.R, headerColor.G, headerColor.B)
        };
        var bandedRowShading = new ShadingPattern
        {
            Fill = Xceed.Drawing.Color.Parse(bandedColor.R, bandedColor.G, bandedColor.B)
        };

        var itemCount = listing.Items.Count;
        // Kopf + Positionen + Leerzeile + Zwischensumme + RVG-Zeile
        var table = document.AddTable(itemCount + 4, 3);
        table.Design = TableDesign.None;
        table.AutoFit = AutoFit.Contents;
        table.Alignment = Alignment.center;

        var thinBorder = new Border(BorderStyle.Tcbs_single, BorderSize.one, 0, Xceed.Drawing.Color.Black);
        var thickBorder = new Border(BorderStyle.Tcbs_single, BorderSize.four, 0, Xceed.Drawing.Color.Black);
        table.SetBorder(TableBorderType.Top, thinBorder);
        table.SetBorder(TableBorderType.Bottom, thinBorder);
        table.SetBorder(TableBorderType.Left, thinBorder);
        table.SetBorder(TableBorderType.Right, thinBorder);
        table.SetBorder(TableBorderType.InsideH, thinBorder);
        table.SetBorder(TableBorderType.InsideV, thinBorder);

        var headerRow = table.Rows[0];
        foreach (var cell in headerRow.Cells)
            cell.ShadingPattern = headerShading;
        ApplyFont(headerRow.Cells[0].Paragraphs[0].Append("Position").Bold(), markerFormatting);
        ApplyFont(headerRow.Cells[1].Paragraphs[0].Append("Bezeichnung").Bold(), markerFormatting);
        ApplyFont(headerRow.Cells[2].Paragraphs[0].Append("Forderung in €").Bold(), markerFormatting)
            .Alignment = Alignment.right;

        for (var index = 0; index < itemCount; index++)
        {
            var item = listing.Items[index];
            var itemRow = table.Rows[index + 1];
            if (index % 2 == 1)
            {
                foreach (var cell in itemRow.Cells)
                    cell.ShadingPattern = bandedRowShading;
            }
            ApplyFont(itemRow.Cells[0].Paragraphs[0].Append((index + 1).ToString(culture)), markerFormatting);
            ApplyFont(itemRow.Cells[1].Paragraphs[0].Append(item.Description), markerFormatting);
            ApplyFont(itemRow.Cells[2].Paragraphs[0]
                    .Append(item.Amount.ToString("N2", culture)), markerFormatting)
                .Alignment = Alignment.right;
        }

        // Leerzeile als optischer Abstand zwischen Positionen und Summen (wie im Excel-Vorbild).

        var subtotalRow = table.Rows[itemCount + 2];
        foreach (var cell in subtotalRow.Cells)
        {
            cell.SetBorder(TableCellBorderType.Top, thickBorder);
            cell.SetBorder(TableCellBorderType.Bottom, thickBorder);
        }
        ApplyFont(subtotalRow.Cells[1].Paragraphs[0]
            .Append("Zwischensumme (ohne RA-Kosten)").Bold(), markerFormatting);
        ApplyFont(subtotalRow.Cells[2].Paragraphs[0]
                .Append(calculation.Gegenstandswert.ToString("N2", culture))
                .Bold(), markerFormatting)
            .Alignment = Alignment.right;

        var rvgRow = table.Rows[itemCount + 3];
        ApplyFont(rvgRow.Cells[1].Paragraphs[0].Append("Anwaltskosten nach RVG"), markerFormatting);
        ApplyFont(rvgRow.Cells[2].Paragraphs[0]
                .Append(calculation.Brutto.ToString("N2", culture)), markerFormatting)
            .Alignment = Alignment.right;

        foreach (var row in table.Rows)
        {
            foreach (var cell in row.Cells)
            {
                foreach (var paragraph in cell.Paragraphs)
                    SetzeKompakteAbsatzabstaende(paragraph);
            }
        }

        return table;
    }

    private static readonly XNamespace W =
        "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    /// <summary>
    /// Setzt die Absatzabstände der Zelle explizit auf kompakt: kein Abstand
    /// davor/danach, einfacher Zeilenabstand (w:line 240 = 1,0).
    ///
    /// Ohne das erben die Zellen die Dokument-Standards der jeweiligen Vorlage —
    /// und die sind bei mit neuerem Word angelegten Vorlagen 8 pt Abstand nach
    /// jedem Absatz plus 1,08-facher Zeilenabstand (w:after 160, w:line 278).
    /// Jede Tabellenzeile war dann fast doppelt so hoch wie ihr Text, und
    /// dieselbe Aufstellung sah je nach Vorlage unterschiedlich hoch aus.
    /// Direkt am XML statt über die DocX-Absatz-API, weil diese eine 0 als
    /// „Attribut entfernen" behandelt — entfernt gilt aber wieder der geerbte
    /// Standard, also genau die 8 pt, die hier wegsollen.
    /// </summary>
    private static void SetzeKompakteAbsatzabstaende(Paragraph paragraph)
    {
        var pPr = paragraph.Xml.Element(W + "pPr");
        if (pPr is null)
        {
            // w:pPr muss das erste Kindelement des Absatzes sein (OOXML-Schema).
            pPr = new XElement(W + "pPr");
            paragraph.Xml.AddFirst(pPr);
        }

        var spacing = pPr.Element(W + "spacing");
        if (spacing is null)
        {
            spacing = new XElement(W + "spacing");
            pPr.Add(spacing);
        }

        spacing.SetAttributeValue(W + "before", "0");
        spacing.SetAttributeValue(W + "after", "0");
        spacing.SetAttributeValue(W + "line", "240");
        spacing.SetAttributeValue(W + "lineRule", "auto");
    }

    /// <summary>Wendet Schriftart und -größe einer Vorlagen-Formatierung auf zuletzt angehängten Text an.</summary>
    private static Paragraph ApplyFont(Paragraph paragraph, Formatting? formatting)
    {
        if (formatting?.FontFamily is not null)
            paragraph.Font(formatting.FontFamily);
        if (formatting?.Size is not null)
            paragraph.FontSize(formatting.Size.Value);
        return paragraph;
    }
}
