using System.IO.Compression;
using System.Text;
using System.Xml;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Der lesbare Text eines Dokuments, so wie ein Mensch ihn saehe -- nicht
/// seine Bytes. Eine .docx ist ein ZIP aus XML, und Word zerlegt eine Zeile in
/// beliebig viele Laeufe: "DE89 3704" kann als "DE8", "9 37" und "04" in drei
/// w:t-Elementen stehen. Gitleaks sucht in den Bytes und sieht dort nichts.
/// </summary>
public static class Dokumentinhalt
{
    /// <summary>
    /// Office Open XML und OpenDocument: der Text aller XML-Teile (Rumpf, Kopf-
    /// und Fusszeilen, Textfelder, Eigenschaften), Absatz fuer Absatz. Alles
    /// andere (alte .doc, PDF, Mail) als Latin-1 und als UTF-16 gelesen --
    /// grob, aber Text steht dort meist in einer der beiden Formen.
    /// </summary>
    public static string Text(byte[] datei)
    {
        if (!IstZip(datei))
        {
            return Roh(datei);
        }

        try
        {
            using var archiv = new ZipArchive(new MemoryStream(datei), ZipArchiveMode.Read);
            var text = new StringBuilder();
            foreach (var teil in archiv.Entries
                         .Where(teil => teil.FullName.EndsWith(".xml", StringComparison.OrdinalIgnoreCase)))
            {
                LiesTeil(teil, text);
                text.Append('\n');
            }

            return text.ToString();
        }
        catch (InvalidDataException)
        {
            // Ein beschaedigtes Archiv bleibt pruefbar, nur grober.
            return Roh(datei);
        }
    }

    static bool IstZip(byte[] datei) =>
        datei is [(byte)'P', (byte)'K', 3, 4, ..];

    static string Roh(byte[] datei) =>
        Encoding.Latin1.GetString(datei) + "\n" + Encoding.Unicode.GetString(datei);

    static void LiesTeil(ZipArchiveEntry teil, StringBuilder text)
    {
        try
        {
            using var leser = XmlReader.Create(teil.Open());
            while (leser.Read())
            {
                switch (leser.NodeType)
                {
                    case XmlNodeType.Text or XmlNodeType.CDATA or XmlNodeType.SignificantWhitespace:
                        text.Append(leser.Value);
                        break;
                    // Tabulator, Umbruch und das Leerzeichen-Element von
                    // OpenDocument trennen Woerter.
                    case XmlNodeType.Element when leser.LocalName is "tab" or "br" or "cr" or "s" or "line-break":
                        text.Append(' ');
                        break;
                    // Absatz, Ueberschrift, Tabellenzelle und Excel-Zeichenkette
                    // trennen Zeilen. Ein Lauf (w:t, w:r) trennt nichts.
                    case XmlNodeType.EndElement when leser.LocalName is "p" or "h" or "tc" or "si" or "v" or "table-cell":
                        text.Append('\n');
                        break;
                }
            }
        }
        catch (XmlException)
        {
            using var strom = teil.Open();
            using var roh = new MemoryStream();
            strom.CopyTo(roh);
            text.Append(Roh(roh.ToArray()));
        }
    }
}
