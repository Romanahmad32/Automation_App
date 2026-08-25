// Einmal-Werkzeug: erzeugt aus den Beispielbriefen parametrisierte Vorlagen mit {{Platzhaltern}}
// für den AutomationService. Bei geänderten Beispieldateien einfach erneut ausführen.
//
// Das Ergebnis landet im Vorlagenordner des Anwenders (%APPDATA%\AutomationService\Vorlagen)
// und NICHT im Repository. Grund: die Ersetzung trifft nur den Fließtext — Kopf- und Fußzeile
// tragen weiterhin Briefkopf, Steuernummer und Bankverbindung der Kanzlei, und der
// Schriftsatztext selbst ist ihre Arbeit. Im Repo liegen nur die neutralen Muster_*.docx.
//
// Die Ersetzungstabelle steht BEWUSST NICHT in dieser Datei: sie bildet die echten
// Mandantendaten des Ausgangsschreibens auf Platzhalter ab (Name, Anschrift, Kennzeichen,
// Versicherungsschein-Nr., Aktenzeichen) und gehört damit nicht ins Repository.
// Sie liegt in `ersetzungen.local.tsv` neben dieser Datei — per .gitignore ausgeschlossen.
// Vorlage mit Platzhalterwerten: `ersetzungen.example.tsv`.
using Xceed.Document.NET;
using Xceed.Words.NET;

var root = Environment.GetEnvironmentVariable("AUTOMATION_APP_ROOT")
           ?? Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));
var templatesDirectory = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
    "AutomationService",
    "Vorlagen");
var mappingPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "ersetzungen.local.tsv");

if (!File.Exists(mappingPath))
{
    Console.Error.WriteLine($"""
        Ersetzungstabelle nicht gefunden: {Path.GetFullPath(mappingPath)}

        Lege sie nach dem Muster von ersetzungen.example.tsv an — eine Zeile je Ersetzung,
        Suchtext und Platzhalter durch einen Tabulator getrennt. Sie enthält echte
        Mandantendaten und darf nicht eingecheckt werden.
        """);
    return 1;
}

// Reihenfolge ist relevant: längere/speziellere Zeichenketten zuerst ersetzen.
// Die Datei gibt die Reihenfolge vor, deshalb wird sie NICHT sortiert.
var replacements = File.ReadAllLines(mappingPath)
    .Select(zeile => zeile.TrimEnd('\r'))
    .Where(zeile => zeile.Length > 0 && !zeile.StartsWith('#'))
    .Select(zeile => zeile.Split('\t', 2))
    .Where(teile => teile.Length == 2)
    .Select(teile => (Search: teile[0], Replace: teile[1]))
    .ToArray();

if (replacements.Length == 0)
{
    Console.Error.WriteLine($"Ersetzungstabelle {Path.GetFullPath(mappingPath)} enthält keine Einträge.");
    return 1;
}

Directory.CreateDirectory(templatesDirectory);
Console.WriteLine($"{replacements.Length} Ersetzungen geladen.");

Parametrize(
    Path.Combine(root, "Beispiele", "VORLAGE Vorfahrtverletzung STOP 205_HGn.docx"),
    Path.Combine(templatesDirectory, "Vorfahrtverletzung_STOP_205_ohne_Auflistung_HGN.docx"),
    insertDamageListingMarker: false);

Parametrize(
    Path.Combine(root, "Beispiele", "VORLAGE Vorfahrtverletzung STOP 205_1 (mit RVG Rechnung).docx"),
    Path.Combine(templatesDirectory, "Vorfahrtverletzung_STOP_205_mit_Auflistung_RVG.docx"),
    insertDamageListingMarker: true);

return 0;

void Parametrize(string sourcePath, string targetPath, bool insertDamageListingMarker)
{
    using var document = DocX.Load(sourcePath);

    foreach (var (search, replace) in replacements)
    {
        document.ReplaceText(new StringReplaceTextOptions
        {
            SearchValue = search,
            NewValue = replace
        });
    }

    if (insertDamageListingMarker)
    {
        var heading = document.Paragraphs.FirstOrDefault(p => p.Text.Contains("SCHADENSAUFSTELLUNG"))
            ?? throw new InvalidOperationException($"Überschrift SCHADENSAUFSTELLUNG nicht gefunden in {sourcePath}");
        heading.InsertParagraphAfterSelf("{{Schadensaufstellung}}");
    }

    document.SaveAs(targetPath);
    Console.WriteLine($"Erstellt: {targetPath}");
}
