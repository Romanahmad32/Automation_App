using System.Diagnostics;
using System.Text.RegularExpressions;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Füllt Word-Vorlagen: lädt die .docx, ersetzt die {{Platzhalter}} und
/// schreibt das Ergebnis in den Arbeitsordner des Vorgangs. Die beiden
/// Sonderfälle der Kanzlei-Vorlagen — die Schadensaufstellung als Tabelle und
/// der Vorsteuer-Ankreuzblock — liegen in <see cref="DamageListingTable"/> und
/// <see cref="VorsteuerCheckbox"/>; die Namensvergabe in
/// <see cref="OutputFileNaming"/>, der Ablageort in
/// <see cref="ArbeitsVerzeichnis"/>.
/// </summary>
public sealed partial class WordAutomationService : IWordAutomationService
{
    private const string PlaceholderPattern = @"\{\{(.*?)\}\}";
    private readonly ILogger<WordAutomationService> _logger;
    private readonly ArbeitsVerzeichnis _arbeitsVerzeichnis;

    public WordAutomationService(
        ILogger<WordAutomationService> logger,
        ArbeitsVerzeichnis arbeitsVerzeichnis)
    {
        _logger = logger;
        _arbeitsVerzeichnis = arbeitsVerzeichnis;
    }

    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        var templatePath = request.TemplateFilePath;
        if (!File.Exists(templatePath))
            throw new FileNotFoundException($"Vorlage nicht gefunden: {templatePath}", templatePath);

        var rawFileName = Path.GetFileNameWithoutExtension(templatePath);
        var replacementValues = BuildReplacementValues(request.ReplacePatterns);
        var unresolvedPlaceholders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var totalStopwatch = Stopwatch.StartNew();
        var stepStopwatch = Stopwatch.StartNew();

        using var document = DocX.Load(templatePath);
        _logger.LogInformation("[PERF] DocX.Load: {Ms} ms", stepStopwatch.ElapsedMilliseconds);

        if (request.DamageListing is { Items.Count: > 0 } damageListing)
        {
            stepStopwatch.Restart();
            DamageListingTable.Insert(document, damageListing, replacementValues);
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

        if (request.Vorsteuerabzugsberechtigt is { } vorsteuerabzugsberechtigt)
        {
            var applied = VorsteuerCheckbox.Apply(document, vorsteuerabzugsberechtigt);
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

        var outputFileName = OutputFileNaming.BuildFileName(request.OutputFileName, rawFileName);
        var outputPath = Path.Combine(
            _arbeitsVerzeichnis.OrdnerFuer(request.VorgangSchluessel),
            outputFileName);
        stepStopwatch.Restart();
        SpeichereUeberschreibend(document, outputPath);
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

    /// <summary>
    /// Schreibt das Ergebnis an denselben Pfad wie der vorige Lauf — eine
    /// Korrektur ersetzt die vorherige Fassung, statt eine "(2)" danebenzulegen.
    /// Bleibend ist erst die Kopie in der Mandantenakte (§4.6).
    ///
    /// Ist die Zieldatei gesperrt (der Anwalt hat sie aus der Prüfung heraus in
    /// Word offen), bricht das bewusst mit einer verständlichen Meldung ab. Die
    /// Alternative — still danebenschreiben — hinterließe zwei Fassungen, von
    /// denen niemand mehr weiß, welche die geprüfte ist.
    /// </summary>
    private static void SpeichereUeberschreibend(DocX document, string outputPath)
    {
        try
        {
            document.SaveAs(outputPath);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            throw new ZieldateiGesperrtException(Path.GetFileName(outputPath), exception);
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

    private static Dictionary<string, string> BuildReplacementValues(IReadOnlyDictionary<string, string> replacePatterns)
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

    // Erlaubt deutsche Platzhalternamen mit Leerzeichen/Umlauten (z. B. "Vorname Mandant", "Straße"),
    // verbietet aber geschweifte Klammern und Steuerzeichen, die die Ersetzung zerstören würden.
    [GeneratedRegex(@"^[\p{L}\p{N} _-]+$", RegexOptions.Compiled)]
    private static partial Regex AllowedPlaceholderKeyPattern();
}
