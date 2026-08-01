using System.Diagnostics;
using System.Globalization;
using System.Text.RegularExpressions;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using Microsoft.Extensions.Options;
using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.WordAutomation.Domain.Services;

public sealed partial class WordAutomationService : IWordAutomationService
{
    private const string PlaceholderPattern = @"\{\{(.*?)\}\}";
    private readonly ILogger<WordAutomationService> _logger;
    private string _outputDirectory;

    public WordAutomationService(
        ILogger<WordAutomationService> logger,
        IOptions<WordAutomationOptions> options,
        IHostEnvironment hostEnvironment)
    {
        _logger = logger;
        var settings = options.Value;
        _outputDirectory = Path.GetFullPath(Path.Combine(hostEnvironment.ContentRootPath, settings.OutputDirectory));
        Directory.CreateDirectory(_outputDirectory);
    }

    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementDto replacementDto)
    {
        ArgumentNullException.ThrowIfNull(replacementDto);

        if (replacementDto.OutputDirectory != "")
        {
            _outputDirectory = Path.GetFullPath(replacementDto.OutputDirectory);
            Directory.CreateDirectory(_outputDirectory);
        }

        var templatePath = replacementDto.TemplateFilePath;
        if (!File.Exists(templatePath))
            throw new FileNotFoundException($"Vorlage nicht gefunden: {templatePath}", templatePath);

        var rawFileName = Path.GetFileNameWithoutExtension(templatePath);
        var replacementValues = BuildReplacementValues(replacementDto.ReplacePatterns);
        var unresolvedPlaceholders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var totalStopwatch = Stopwatch.StartNew();
        var stepStopwatch = Stopwatch.StartNew();

        using var document = DocX.Load(templatePath);
        _logger.LogInformation("[PERF] DocX.Load: {Ms} ms", stepStopwatch.ElapsedMilliseconds);

        if (replacementDto.DamageListing is { Items.Count: > 0 } damageListing)
        {
            stepStopwatch.Restart();
            InsertDamageListing(document, damageListing, replacementValues);
            _logger.LogInformation("[PERF] InsertDamageListing: {Ms} ms", stepStopwatch.ElapsedMilliseconds);
        }

        // Hinweis: Der frühere Vorab-Scan via FindUniqueByPattern wurde entfernt.
        // Er war rein redundant – er hat nur geprüft, ob Platzhalter existieren,
        // bevor ReplaceText denselben Scan nochmal vollständig durchführt.
        // ReplaceText ist ein No-op, falls keine Platzhalter vorhanden sind, und
        // der RegexMatchHandler trackt unaufgelöste Platzhalter ohnehin selbst.
        stepStopwatch.Restart();
        document.ReplaceText(new FunctionReplaceTextOptions
        {
            FindPattern = PlaceholderPattern,
            RegExOptions = RegexOptions.IgnoreCase,
            // Kein NewFormatting setzen: null übernimmt die Formatierung des ersetzten
            // Platzhalters; ein leeres Formatting() würde auf die Dokument-Standardschrift
            // (z. B. Times New Roman) zurückfallen.
            RegexMatchHandler = key =>
            {
                if (replacementValues.TryGetValue(key, out var value))
                    return value;
                unresolvedPlaceholders.Add(key);
                return $"{{{{{key}}}}}";
            }
        });
        _logger.LogInformation("[PERF] ReplaceText: {Ms} ms", stepStopwatch.ElapsedMilliseconds);

        var warnings = new List<string>(unresolvedPlaceholders);

        if (replacementDto.Vorsteuerabzugsberechtigt is { } vorsteuerabzugsberechtigt)
        {
            var applied = ApplyVorsteuerCheckbox(document, vorsteuerabzugsberechtigt);
            if (!applied)
            {
                _logger.LogInformation(
                    "Vorsteuer-Block in Vorlage {Template} nicht gefunden – Ankreuzen übersprungen.",
                    templatePath);
                warnings.Add(
                    "Der Abschnitt \"vorsteuerabzugsberechtigt\" wurde in der Vorlage nicht gefunden; " +
                    "das Kästchen konnte nicht automatisch gesetzt werden.");
            }
        }

        var outputFileName = BuildOutputFileName(replacementDto.OutputFileName, rawFileName);
        var outputPath = EnsureUniquePath(Path.Combine(_outputDirectory, outputFileName));
        stepStopwatch.Restart();
        document.SaveAs(outputPath);
        _logger.LogInformation("[PERF] SaveAs: {Ms} ms", stepStopwatch.ElapsedMilliseconds);
        _logger.LogInformation("[PERF] GenerateReplacedDocument GESAMT: {Ms} ms", totalStopwatch.ElapsedMilliseconds);

        if (unresolvedPlaceholders.Count > 0)
        {
            _logger.LogWarning(
                "Document generated with unresolved placeholders for template {Template}: {Placeholders}",
                templatePath,
                string.Join(", ", unresolvedPlaceholders));
        }

        return new DocumentGenerationResult(outputPath, warnings);
    }

    public IReadOnlyList<string> ExtractPlaceholders(string templateFilePath)
    {
        if (string.IsNullOrWhiteSpace(templateFilePath))
            throw new ArgumentException("TemplateFilePath is required.", nameof(templateFilePath));

        if (!File.Exists(templateFilePath))
            throw new FileNotFoundException($"Vorlage nicht gefunden: {templateFilePath}", templateFilePath);

        using var document = DocX.Load(templateFilePath);
        var matches = document.FindUniqueByPattern(PlaceholderPattern, RegexOptions.IgnoreCase);

        // Defensiv die geschweiften Klammern entfernen, falls die Bibliothek den
        // Gesamttreffer ("{{Name}}") statt der Capture-Group ("Name") liefert.
        return matches
            .Select(match => match.Trim().Trim('{', '}').Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public void Warmup()
    {
        var stopwatch = Stopwatch.StartNew();
        string? createPath = null;
        string? outputPath = null;
        try
        {
            createPath = Path.Combine(Path.GetTempPath(), $"docx_warmup_{Guid.NewGuid():N}.docx");
            outputPath = Path.Combine(Path.GetTempPath(), $"docx_warmup_{Guid.NewGuid():N}_out.docx");

            // Erzeugt + speichert ein Dokument mit Platzhalter (JIT für Create/Save).
            using (var created = DocX.Create(createPath))
            {
                created.InsertParagraph("{{Warmup}} – Aufwärmtext, damit der JIT vorab läuft.");
                created.Save();
            }

            // Lädt, ersetzt und speichert es erneut – dieselben Pfade wie im echten Request.
            using var document = DocX.Load(createPath);
            document.ReplaceText(new FunctionReplaceTextOptions
            {
                FindPattern = PlaceholderPattern,
                RegExOptions = RegexOptions.IgnoreCase,
                RegexMatchHandler = _ => "ok"
            });
            document.SaveAs(outputPath);

            _logger.LogInformation("[PERF] Warmup der DocX-Pipeline abgeschlossen: {Ms} ms", stopwatch.ElapsedMilliseconds);
        }
        catch (Exception exception)
        {
            // Warmup ist optional – ein Fehler darf den Start nicht beeinträchtigen.
            _logger.LogWarning(exception, "Warmup der DocX-Pipeline fehlgeschlagen (unkritisch).");
        }
        finally
        {
            TryDeleteFile(createPath);
            TryDeleteFile(outputPath);
        }
    }

    private static void TryDeleteFile(string? path)
    {
        if (string.IsNullOrEmpty(path))
            return;
        try
        {
            if (File.Exists(path))
                File.Delete(path);
        }
        catch
        {
            // Aufräumen ist Best-Effort.
        }
    }

    private const string DamageListingPlaceholder = "{{Schadensaufstellung}}";

    /// <summary>
    /// Fügt am Platzhalter {{Schadensaufstellung}} eine Tabelle mit den Schadenspositionen ein
    /// und stellt die RVG-Kostenkalkulation als zusätzliche Platzhalterwerte bereit.
    /// </summary>
    private static void InsertDamageListing(DocX document, DamageListingDto damageListing, Dictionary<string, string> replacementValues)
    {
        var culture = CultureInfo.GetCultureInfo("de-DE");
        var gegenstandswert = damageListing.Items.Sum(item => item.Amount);
        var calculation = RvgFeeCalculator.Calculate(
            gegenstandswert,
            damageListing.Gebuehrensatz,
            damageListing.ApplyVat,
            damageListing.GeschaeftsgebuehrOverride,
            damageListing.AuslagenpauschaleOverride);

        replacementValues["Gegenstandswert"] = calculation.Gegenstandswert.ToString("N2", culture);
        replacementValues["Gebuehrensatz"] = calculation.Gebuehrensatz.ToString("0.0#", culture);
        replacementValues["Geschaeftsgebuehr"] = calculation.Geschaeftsgebuehr.ToString("N2", culture);
        replacementValues["Auslagenpauschale"] = calculation.Auslagenpauschale.ToString("N2", culture);
        replacementValues["RvgNetto"] = calculation.Netto.ToString("N2", culture);
        replacementValues["RvgUmsatzsteuer"] = calculation.Umsatzsteuer.ToString("N2", culture);
        replacementValues["RvgBrutto"] = calculation.Brutto.ToString("N2", culture);

        var markerParagraph = document.Paragraphs.FirstOrDefault(paragraph =>
            paragraph.Text.Contains(DamageListingPlaceholder, StringComparison.OrdinalIgnoreCase));
        if (markerParagraph is null)
        {
            throw new TemplateProcessingException(
                $"Die Vorlage enthält keinen Platzhalter {DamageListingPlaceholder}. " +
                "Für eine Schadensaufstellung muss eine Vorlage mit Auflistung verwendet werden.");
        }

        // Schrift des Marker-Absatzes übernehmen, damit die Tabelle nicht in der
        // Dokument-Standardschrift (z. B. Times New Roman) erscheint.
        var markerFormatting = markerParagraph.MagicText
            .Select(magicText => magicText.formatting)
            .FirstOrDefault(formatting => formatting is not null);

        var table = BuildDamageListingTable(document, damageListing, calculation, markerFormatting, culture);

        markerParagraph.InsertTableBeforeSelf(table);
        markerParagraph.Remove(false);
    }

    // Standardfarbe wie im Excel-Vorbild der Kanzlei (eingebettete Tabelle in
    // "VORLAGE Fahrspurwechsel mit Auflistung"): grauer Kopf, dezente Zebra-Streifen.
    private const string DefaultHeaderColorHex = "D9D9D9";

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

    /// <summary>
    /// Baut die Schadensaufstellungs-Tabelle im Layout der bisher manuell eingebetteten
    /// Excel-Aufstellung: Position | Bezeichnung | Forderung in €, Positionszeilen mit
    /// Zebra-Streifen, Leerzeile, Zwischensumme (dick umrandet) und RA-Kosten – horizontal
    /// zentriert. (Das Excel-OLE-Objekt selbst kann DocX nicht befüllen: Word zeigt davon
    /// nur ein gecachtes Bild, das bei programmatischen Änderungen veraltet bliebe.)
    /// </summary>
    private static Table BuildDamageListingTable(
        DocX document,
        DamageListingDto damageListing,
        RvgCalculation calculation,
        Formatting? markerFormatting,
        CultureInfo culture)
    {
        var headerColor = ParseHeaderColor(damageListing.HeaderColorHex);
        var bandedColor = LightenForBandedRows(headerColor);
        var headerShading = new ShadingPattern
        {
            Fill = Xceed.Drawing.Color.Parse(headerColor.R, headerColor.G, headerColor.B)
        };
        var bandedRowShading = new ShadingPattern
        {
            Fill = Xceed.Drawing.Color.Parse(bandedColor.R, bandedColor.G, bandedColor.B)
        };

        var itemCount = damageListing.Items.Count;
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
            var item = damageListing.Items[index];
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

        return table;
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

    private const char VorsteuerCheckedBox = '☒'; // U+2612
    private const char VorsteuerEmptyBox = '☐';   // U+2610
    private const string VorsteuerAnchor = "vorsteuerabzugsberechtigt";

    /// <summary>
    /// Kreuzt im Block "Mein Mandant ☐ ist / ☐ ist nicht vorsteuerabzugsberechtigt"
    /// das passende Kästchen an. Die Vorlagen kreuzen auf zwei Arten an:
    /// (a) literale Unicode-Kästchen (☐ U+2610 / ☒ U+2612) im Fließtext oder
    /// (b) Word-Kontrollkästchen (Inhaltssteuerelement &lt;w:sdt&gt; mit
    /// &lt;w14:checkbox&gt;), bei denen Zustand (&lt;w14:checked&gt;) und
    /// angezeigtes Glyph getrennt gesetzt werden müssen.
    ///
    /// Da es keine Platzhalter gibt, wird der Block heuristisch über den Anker
    /// "vorsteuerabzugsberechtigt" gefunden. Anker und Kästchen können in
    /// getrennten Absätzen stehen; deshalb wird ab dem Anker rückwärts ein
    /// kleines Fenster nach den beiden Kästchen-Absätzen durchsucht und über das
    /// Wort "nicht" in Positiv-/Negativ-Zeile klassifiziert.
    /// Gibt false zurück, wenn kein solcher Block gefunden wurde.
    /// </summary>
    private static bool ApplyVorsteuerCheckbox(DocX document, bool vorsteuerabzugsberechtigt)
    {
        var paragraphs = document.Paragraphs;

        var anchorIndex = -1;
        for (var i = 0; i < paragraphs.Count; i++)
        {
            if (paragraphs[i].Text.Contains(VorsteuerAnchor, StringComparison.OrdinalIgnoreCase))
            {
                anchorIndex = i;
                break;
            }
        }
        if (anchorIndex < 0)
            return false;

        Paragraph? positive = null;
        Paragraph? negative = null;
        for (var i = anchorIndex; i >= 0 && i >= anchorIndex - 8; i--)
        {
            var paragraph = paragraphs[i];
            if (!HasCheckbox(paragraph))
                continue;

            // Negativ-Zeile = "… ist nicht …", Positiv-Zeile = "… ist".
            if (paragraph.Text.Contains("nicht", StringComparison.OrdinalIgnoreCase))
                negative ??= paragraph;
            else
                positive ??= paragraph;

            if (positive is not null && negative is not null)
                break;
        }

        if (negative is null)
            return false;

        // "ist nicht vorsteuerabzugsberechtigt" ist angekreuzt, wenn der Mandant
        // gerade NICHT vorsteuerabzugsberechtigt ist – und umgekehrt.
        SetCheckboxState(negative, isChecked: !vorsteuerabzugsberechtigt);
        if (positive is not null)
            SetCheckboxState(positive, isChecked: vorsteuerabzugsberechtigt);

        return true;
    }

    /// <summary>True, wenn der Absatz ein literales Kästchen-Glyph oder ein
    /// Word-Kontrollkästchen (w14:checkbox) enthält.</summary>
    private static bool HasCheckbox(Paragraph paragraph)
    {
        if (paragraph.Text.Contains(VorsteuerEmptyBox) || paragraph.Text.Contains(VorsteuerCheckedBox))
            return true;
        return paragraph.Xml.Descendants().Any(element => element.Name.LocalName == "checkbox");
    }

    /// <summary>
    /// Setzt den Zustand des Kästchens im Absatz. Bei Word-Kontrollkästchen werden
    /// sowohl &lt;w14:checked&gt; als auch das angezeigte Glyph gesetzt; sonst wird
    /// das literale Glyph ersetzt (No-op, wenn bereits korrekt).
    /// </summary>
    private static void SetCheckboxState(Paragraph paragraph, bool isChecked)
    {
        var glyph = isChecked ? VorsteuerCheckedBox : VorsteuerEmptyBox;

        var checkboxSdts = paragraph.Xml
            .Descendants()
            .Where(element => element.Name.LocalName == "sdt"
                && element.Descendants().Any(child => child.Name.LocalName == "checkbox"))
            .ToList();

        if (checkboxSdts.Count > 0)
        {
            foreach (var sdt in checkboxSdts)
            {
                var checkedElement = sdt.Descendants()
                    .FirstOrDefault(element => element.Name.LocalName == "checked");
                var valAttribute = checkedElement?.Attributes()
                    .FirstOrDefault(attribute => attribute.Name.LocalName == "val");
                if (valAttribute is not null)
                    valAttribute.Value = isChecked ? "1" : "0";

                var sdtContent = sdt.Elements()
                    .FirstOrDefault(element => element.Name.LocalName == "sdtContent");
                var textElement = sdtContent?.Descendants()
                    .FirstOrDefault(element => element.Name.LocalName == "t");
                textElement?.SetValue(glyph.ToString());
            }
            return;
        }

        // Literales Glyph: das jeweils andere Kästchen durch das gewünschte ersetzen.
        var other = isChecked ? VorsteuerEmptyBox : VorsteuerCheckedBox;
        paragraph.ReplaceText(new StringReplaceTextOptions
        {
            SearchValue = other.ToString(),
            NewValue = glyph.ToString(),
            EscapeRegEx = true,
            StopAfterOneReplacement = true
        });
    }

    private static Dictionary<string, string> BuildReplacementValues(Dictionary<string, string> replacePatterns)
    {
        if (replacePatterns is null)
            throw new ArgumentException("ReplacePatterns is required.", nameof(replacePatterns));

        // Das Datum wird nicht mehr serverseitig injiziert ({{Today}} entfällt):
        // Das Frontend liefert es als reguläres, vom Anwender editierbares Feld mit.
        var values = new Dictionary<string, string>(replacePatterns, StringComparer.OrdinalIgnoreCase);

        foreach (var key in values.Keys)
        {
            if (!AllowedPlaceholderKeyPattern().IsMatch(key))
            {
                throw new ArgumentException(
                    $"Platzhalter-Schlüssel '{key}' ist ungültig. Erlaubt sind Buchstaben (inkl. Umlaute), " +
                    "Ziffern, Leerzeichen, '_' und '-' – aber keine geschweiften Klammern oder Zeilenumbrüche.",
                    nameof(replacePatterns));
            }
        }

        return values;
    }

    /// <summary>
    /// Bestimmt den Ausgabedateinamen. Nutzt den gewünschten Namen (auf den reinen Dateinamen
    /// reduziert, um Verzeichniswechsel zu verhindern) oder fällt auf "{Vorlage}_{Datum}" zurück.
    /// Punkte im Namen (z. B. Datumsangaben "12.05.2025") bleiben erhalten; nur eine bereits
    /// angehängte .docx/.doc-Endung wird entfernt.
    /// </summary>
    private static string BuildOutputFileName(string requestedName, string templateName)
    {
        if (!string.IsNullOrWhiteSpace(requestedName))
        {
            // Nur das Verzeichnis abschneiden (Schutz vor Pfadwechsel).
            var safeName = Path.GetFileName(requestedName.Trim());
            foreach (var ext in new[] { ".docx", ".doc" })
            {
                if (safeName.EndsWith(ext, StringComparison.OrdinalIgnoreCase))
                {
                    safeName = safeName[..^ext.Length];
                    break;
                }
            }
            // Abschließende Punkte/Leerzeichen sind unter Windows als Dateiname unzulässig.
            safeName = safeName.Trim().TrimEnd('.', ' ');
            if (!string.IsNullOrWhiteSpace(safeName))
                return safeName + ".docx";
        }

        return $"{templateName}_{DateTime.Now:yyyy-MM-dd}.docx";
    }

    /// <summary>Hängt " (2)", " (3)" … an, falls die Zieldatei bereits existiert, statt sie zu überschreiben.</summary>
    private static string EnsureUniquePath(string path)
    {
        if (!File.Exists(path))
            return path;

        var directory = Path.GetDirectoryName(path)!;
        var name = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);

        for (var counter = 2; ; counter++)
        {
            var candidate = Path.Combine(directory, $"{name} ({counter}){extension}");
            if (!File.Exists(candidate))
                return candidate;
        }
    }

    // Erlaubt deutsche Platzhalternamen mit Leerzeichen/Umlauten (z. B. "Vorname Mandant", "Straße"),
    // verbietet aber geschweifte Klammern und Steuerzeichen, die die Ersetzung zerstören würden.
    [GeneratedRegex(@"^[\p{L}\p{N} _-]+$", RegexOptions.Compiled)]
    private static partial Regex AllowedPlaceholderKeyPattern();
}
