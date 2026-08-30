using System.Xml.Linq;
using Xceed.Document.NET;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Das Aussehen des Register-Spiegels — bewusst getrennt vom Zusammenbau der
/// Zeilen (<see cref="RegisterDokument"/>), weil hier die Entscheidungen
/// stehen, die aus der Vorlagendatei der Kanzlei stammen, und dort die, die aus
/// den Daten stammen.
///
/// Übernommen aus der Vorlagendatei: Century Gothic, 8 pt, A4 hoch, die
/// Spaltenreihenfolge und die fetten Jahresüberschriften.
///
/// <b>Nicht</b> übernommen — die Datei hat sie, aber sie sind Mängel und keine
/// Konvention (aus dem OOXML der Vorlage gelesen, #40):
/// <list type="bullet">
///   <item>kein <c>tblHeader</c>: die Spaltenüberschriften stehen dort nur auf
///     Seite 1, auf den übrigen 92 Seiten steht man ohne sie da;</item>
///   <item>kein <c>tblBorders</c>: 93 Seiten Tabelle ganz ohne Linien;</item>
///   <item>Kopfzeile in Times New Roman/Calibri, Körper in Century Gothic;</item>
///   <item>Tabellenbreite 9216 Twips bei 9072 Twips Satzspiegel — die Tabelle
///     ragt über den rechten Rand.</item>
/// </list>
/// </summary>
public static class RegisterLayout
{
    public const string Schriftart = "Century Gothic";
    public const double Schriftgrad = 8d;

    /// <summary>Überschrift über der Tabelle, zugleich die erste PDF-Sprungmarke.</summary>
    public const string Titel = "Sachgebiete-Register";

    /// <summary>
    /// Der Satz, der die Datei als Spiegel kenntlich macht. Er steht im Dokument
    /// und nicht nur im Dateinamen, weil er damit der einzige Schutz ist, der
    /// auf jedem Gerät ankommt — auf dem Handy, im Web, im Ausdruck. Ein
    /// Schreibschutz-Attribut tut das nicht.
    /// </summary>
    public const string Spiegelhinweis =
        "Automatisch erzeugt aus der Kanzlei-App. Gepflegt wird das Register in der App — "
        + "Änderungen an dieser Datei gehen beim nächsten Schreiben verloren.";

    /// <summary>Erklärt die Auszeichnung nicht abgeschlossener Zeilen.</summary>
    public const string Legende =
        "Kursiv gesetzte Zeilen sind noch nicht abgeschlossen; ihre laufende Nummer "
        + "wird erst beim Abschluss vergeben.";

    public static readonly string[] Spaltenkoepfe =
        ["Lfd. Nr.", "Zeichen", "Name ./. Gegner · Sachbestand", "Rechtsgebiet"];

    /// <summary>
    /// Spaltenbreiten in Twips. Zusammen 9000 und damit innerhalb des
    /// Satzspiegels von 9072 Twips (A4 hoch, 2,5 cm Rand) — anders als in der
    /// Vorlagendatei, deren Tabelle rechts hinausragt.
    /// </summary>
    public static readonly int[] SpaltenbreitenTwips = [700, 1500, 4400, 2400];

    static readonly XNamespace W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    /// <summary>Die Standardformatierung jeder Zelle.</summary>
    public static Formatting Zellenschrift(bool fett = false, bool kursiv = false) => new()
    {
        FontFamily = new Xceed.Document.NET.Font(Schriftart),
        Size = Schriftgrad,
        Bold = fett,
        Italic = kursiv,
    };

    /// <summary>
    /// Setzt Rahmen und feste Spaltenbreiten. <see cref="AutoFit.Fixed"/> ist
    /// Absicht: Bei <c>Contents</c> bestimmte der längste Mandantenname die
    /// Breite, und die Tabelle wanderte mit jedem neuen Vorgang.
    /// </summary>
    public static void Rahmen(Table tabelle)
    {
        tabelle.Design = TableDesign.None;
        tabelle.AutoFit = AutoFit.Fixed;

        var linie = new Border(BorderStyle.Tcbs_single, BorderSize.one, 0, Xceed.Drawing.Color.Parse(150, 150, 150));
        foreach (var seite in new[]
                 {
                     TableBorderType.Top, TableBorderType.Bottom, TableBorderType.Left,
                     TableBorderType.Right, TableBorderType.InsideH, TableBorderType.InsideV,
                 })
        {
            tabelle.SetBorder(seite, linie);
        }

        SetzeSpaltenbreiten(tabelle);
    }

    /// <summary>
    /// Schreibt <c>tblGrid</c> und die Zellenbreiten direkt in Twips — dieselbe
    /// Einheit, in der die Vorlagendatei vermessen wurde. Über die
    /// Komfortmethoden von DocX ginge das nur über eine Umrechnung in Punkte
    /// und damit über einen Rundungsfehler je Spalte.
    /// </summary>
    static void SetzeSpaltenbreiten(Table tabelle)
    {
        var raster = tabelle.Xml.Element(W + "tblGrid");
        raster?.Remove();
        tabelle.Xml.Add(new XElement(
            W + "tblGrid",
            SpaltenbreitenTwips.Select(breite =>
                new XElement(W + "gridCol", new XAttribute(W + "w", breite)))));

        foreach (var zeile in tabelle.Xml.Elements(W + "tr"))
        {
            var zellen = zeile.Elements(W + "tc").ToList();
            // Verbundene Zeilen (Jahresüberschriften) haben nur eine Zelle; ihre
            // Breite steht dort schon und darf nicht auf Spalte 1 gestutzt werden.
            if (zellen.Count != SpaltenbreitenTwips.Length) continue;
            for (var i = 0; i < zellen.Count; i++) SetzeZellenbreite(zellen[i], SpaltenbreitenTwips[i]);
        }
    }

    static void SetzeZellenbreite(XElement zelle, int twips)
    {
        var eigenschaften = zelle.Element(W + "tcPr");
        if (eigenschaften is null)
        {
            eigenschaften = new XElement(W + "tcPr");
            zelle.AddFirst(eigenschaften);
        }

        eigenschaften.Element(W + "tcW")?.Remove();
        eigenschaften.AddFirst(new XElement(
            W + "tcW",
            new XAttribute(W + "w", twips),
            new XAttribute(W + "type", "dxa")));
    }

    /// <summary>
    /// Markiert die Zeile als Tabellenkopf, sodass Word sie auf jeder Seite
    /// wiederholt. Genau das fehlt der Vorlagendatei — der Grund, warum ihre
    /// Spalten ab Seite 2 geraten werden müssen.
    /// </summary>
    public static void AlsWiederholtenKopfMarkieren(Row zeile)
    {
        var eigenschaften = zeile.Xml.Element(W + "trPr");
        if (eigenschaften is null)
        {
            eigenschaften = new XElement(W + "trPr");
            zeile.Xml.AddFirst(eigenschaften);
        }

        if (eigenschaften.Element(W + "tblHeader") is null)
            eigenschaften.Add(new XElement(W + "tblHeader"));
    }
}
