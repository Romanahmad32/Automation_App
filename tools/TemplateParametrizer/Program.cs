// Einmal-Werkzeug: erzeugt aus den Beispielbriefen parametrisierte Vorlagen mit {{Platzhaltern}}
// für den AutomationService. Bei geänderten Beispieldateien einfach erneut ausführen.
//
// Das Ergebnis landet im Vorlagenordner des Anwenders (AUTOMATION_APP_VORLAGEN, sonst
// %APPDATA%\AutomationService\Vorlagen) und NICHT im Repository. Grund: Briefkopf,
// Steuernummer und Bankverbindung der Kanzlei bleiben stehen — parametrisiert wird nur,
// was von Mandat zu Mandat wechselt (im Briefkopf also Zeichen und Datum, nicht die
// Anschrift der Kanzlei) — und der Schriftsatztext selbst ist ihre Arbeit. Im Repo liegen
// nur die neutralen Muster_*.docx.
//
// Die Ersetzungstabelle steht BEWUSST NICHT in dieser Datei: sie bildet die echten
// Mandantendaten des Ausgangsschreibens auf Platzhalter ab (Name, Anschrift, Kennzeichen,
// Versicherungsschein-Nr., Aktenzeichen) und gehört damit nicht ins Repository.
// Sie liegt in `ersetzungen.local.tsv` neben dieser Datei — per .gitignore ausgeschlossen.
// Vorlage mit Platzhalterwerten: `ersetzungen.example.tsv`.
using System.IO.Compression;
using System.Text;
using System.Xml;
using System.Xml.Linq;
using Xceed.Document.NET;
using Xceed.Words.NET;

var root = Environment.GetEnvironmentVariable("AUTOMATION_APP_ROOT")
           ?? Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));
// Der Vorlagenordner ist in der App eine Einstellung (#33) und liegt nicht
// zwingend unter %APPDATA% -- wer ihn verlegt hat, nennt ihn hier, sonst
// schreibt das Werkzeug an einer laufenden App vorbei.
var templatesDirectory = Environment.GetEnvironmentVariable("AUTOMATION_APP_VORLAGEN")
    ?? Path.Combine(
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
    Path.Combine(templatesDirectory, "Vorfahrtverletzung_STOP_205_ohne_Auflistung_HGn.docx"),
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
    NachleseInAltenZweigen(targetPath, replacements);
    Console.WriteLine($"Erstellt: {targetPath}");
}

// DocX ersetzt in einem <mc:AlternateContent> nur den <mc:Choice>-Zweig. Der
// <mc:Fallback>-Zweig daneben -- was aeltere Renderer zeichnen, und damit auch
// der FreeSpire-Weg der PDF-Umwandlung, wenn Word nicht verfuegbar ist -- behaelt
// den Ausgangstext. Im Briefkopf der Kanzleivorlagen steht dort das Zeichen und
// das Datum des Ausgangsschreibens: ausgerechnet die Mandantendaten, die diese
// Parametrisierung entfernen soll. Sie blieben unsichtbar stehen, bis irgendwann
// ein Renderer den Fallback zeichnet und ein fremdes Aktenzeichen im Brief steht.
//
// Diese Nachlese geht deshalb ueber die gespeicherte Datei und wendet dieselbe
// Tabelle noch einmal an -- aber AUSSCHLIESSLICH innerhalb der
// <mc:Fallback>-Zweige. Ueber die ganze Datei zu laufen waere ein zweiter
// Durchgang ueber Text, den DocX schon richtig ersetzt hat: Traegt das Ergebnis
// einer Zeile den Suchtext einer spaeteren ("{{Gebuehrensatz}} Geschaeftsgebuehr"
// gegen eine Zeile, die "Geschaeftsgebuehr" sucht), griffe sie ein zweites Mal.
// Sie findet nur, was innerhalb EINES Textelements steht -- ueber Laeufe
// verteilte Treffer hat DocX erledigt, und im Fallback steht der Text am Stueck.
static void NachleseInAltenZweigen(string docxPath, (string Search, string Replace)[] tabelle)
{
    XNamespace w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    XNamespace mc = "http://schemas.openxmlformats.org/markup-compatibility/2006";
    // Weder neu einruecken noch ein BOM voranstellen: Sonst schreibt die
    // Nachlese die komplette document.xml der Kanzleivorlage um, statt nur die
    // paar Elemente, die sie geaendert hat.
    var einstellungen = new XmlWriterSettings
    {
        Indent = false,
        Encoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false),
    };
    using var archiv = ZipFile.Open(docxPath, ZipArchiveMode.Update);

    foreach (var eintrag in archiv.Entries.Where(IstTextteil).ToList())
    {
        XDocument xml;
        using (var lesen = eintrag.Open())
            xml = XDocument.Load(lesen);

        var geaendert = false;
        foreach (var textElement in xml.Descendants(mc + "Fallback")
                     .SelectMany(zweig => zweig.Descendants(w + "t")))
        {
            var text = textElement.Value;
            foreach (var (search, replace) in tabelle)
                text = text.Replace(search, replace, StringComparison.Ordinal);

            if (text == textElement.Value)
                continue;

            // Ohne xml:space="preserve" wirft Word fuehrende und folgende
            // Leerzeichen weg -- aus "Zeichen:   {{Zeichen}}" wuerde sonst
            // beim naechsten Speichern ein zusammengezogener Text.
            if (text != text.Trim())
                textElement.SetAttributeValue(XNamespace.Xml + "space", "preserve");

            textElement.SetValue(text);
            geaendert = true;
        }

        if (!geaendert)
            continue;

        using var schreiben = eintrag.Open();
        schreiben.SetLength(0);
        using var schreiber = XmlWriter.Create(schreiben, einstellungen);
        xml.Save(schreiber);
    }
}

// Der Fliesstext und die Kopf-/Fusszeilen -- nur dort steht sichtbarer Text.
static bool IstTextteil(ZipArchiveEntry eintrag) =>
    eintrag.FullName.StartsWith("word/", StringComparison.Ordinal)
    && eintrag.FullName.EndsWith(".xml", StringComparison.Ordinal)
    && (eintrag.Name == "document.xml"
        || eintrag.Name.StartsWith("header", StringComparison.Ordinal)
        || eintrag.Name.StartsWith("footer", StringComparison.Ordinal));
