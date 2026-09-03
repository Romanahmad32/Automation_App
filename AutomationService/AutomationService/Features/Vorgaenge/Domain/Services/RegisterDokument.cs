using System.Globalization;
using AutomationService.Core.Ablage;
using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Schreibt die Registerzeilen als frische Word-Tabelle (§6.2, #40).
///
/// „Frisch" ist der Kern: Die App schreibt nicht mehr in das gewachsene
/// 93-Seiten-Dokument der Kanzlei hinein, sondern gibt dasselbe Spaltenschema
/// neu aus. Damit erbt der Export keine seiner Unstimmigkeiten — welche das
/// sind und was stattdessen gilt, steht in <see cref="RegisterLayout"/>.
///
/// Die Datei entsteht immer dort, wo sie gebaut wird, und nicht am Zielort;
/// das Umziehen macht <see cref="AtomareAblage"/>.
/// </summary>
public static class RegisterDokument
{
    /// <summary>
    /// Baut das Dokument nach <paramref name="zielDatei"/>.
    /// </summary>
    /// <param name="zielDatei">Wohin gebaut wird — nie der endgültige Ablageort.</param>
    /// <param name="zeilen">Die fertig sortierten und gefilterten Registerzeilen.</param>
    /// <param name="erzeugtAm">
    /// Steht im Kopf der Datei. Übergeben statt hier gelesen, damit die
    /// Ausgabe für einen Test vorhersagbar ist.
    /// </param>
    /// <param name="nurAbgeschlossene">
    /// Bestimmt die Zeile unter dem Titel, die sagt, was in der Datei steht.
    /// Ohne sie wäre einer Datei mit 40 Zeilen nicht anzusehen, ob 40 Vorgänge
    /// existieren oder ob der Rest nur weggefiltert ist.
    /// </param>
    public static void Schreibe(
        string zielDatei,
        IReadOnlyList<RegisterZeile> zeilen,
        DateTime erzeugtAm,
        bool nurAbgeschlossene)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(zielDatei);
        ArgumentNullException.ThrowIfNull(zeilen);

        using var dokument = DocX.Create(zielDatei);
        dokument.PageLayout.Orientation = Orientation.Portrait;

        Kopf(dokument, erzeugtAm, zeilen.Count, nurAbgeschlossene);
        if (zeilen.Count > 0) dokument.InsertTable(Tabelle(dokument, zeilen));
        Fuss(dokument, zeilen);

        dokument.Save();
    }

    static void Kopf(DocX dokument, DateTime erzeugtAm, int anzahl, bool nurAbgeschlossene)
    {
        var kultur = CultureInfo.GetCultureInfo("de-DE");

        var titel = dokument.InsertParagraph(RegisterLayout.Titel);
        titel.Font(new Xceed.Document.NET.Font(RegisterLayout.Schriftart)).FontSize(14).Bold();
        titel.StyleId = "Heading1";

        var umfang = nurAbgeschlossene
            ? $"{anzahl} abgeschlossene Vorgänge"
            : $"{anzahl} Vorgänge (einschließlich der noch nicht abgeschlossenen)";
        Kleingedrucktes(dokument, $"Stand {erzeugtAm.ToString("dd.MM.yyyy HH:mm", kultur)} · {umfang}");
        Kleingedrucktes(dokument, RegisterLayout.Spiegelhinweis);
        dokument.InsertParagraph(string.Empty);
    }

    static void Fuss(DocX dokument, IReadOnlyList<RegisterZeile> zeilen)
    {
        if (zeilen.Count == 0)
        {
            Kleingedrucktes(dokument, "Noch keine Vorgänge erfasst.");
            return;
        }

        if (zeilen.Any(z => !z.Abgeschlossen))
        {
            dokument.InsertParagraph(string.Empty);
            Kleingedrucktes(dokument, RegisterLayout.Legende);
        }
    }

    static void Kleingedrucktes(DocX dokument, string text) =>
        dokument.InsertParagraph(text)
            .Font(new Xceed.Document.NET.Font(RegisterLayout.Schriftart))
            .FontSize(RegisterLayout.Schriftgrad)
            .Color(Xceed.Drawing.Color.Parse(90, 90, 90));

    static Table Tabelle(DocX dokument, IReadOnlyList<RegisterZeile> zeilen)
    {
        var jahrgaenge = zeilen.Select(z => z.Jahr).Distinct().Count();
        var tabelle = dokument.AddTable(1 + jahrgaenge + zeilen.Count, RegisterLayout.Spaltenkoepfe.Length);

        Kopfzeile(tabelle.Rows[0]);

        var index = 1;
        string? letztesJahr = null;
        foreach (var zeile in zeilen)
        {
            if (zeile.Jahr != letztesJahr)
            {
                Jahreszeile(tabelle.Rows[index++], zeile.Jahr);
                letztesJahr = zeile.Jahr;
            }
            Datenzeile(tabelle.Rows[index++], zeile);
        }

        RegisterLayout.Rahmen(tabelle);
        return tabelle;
    }

    static void Kopfzeile(Row zeile)
    {
        for (var spalte = 0; spalte < RegisterLayout.Spaltenkoepfe.Length; spalte++)
        {
            zeile.Cells[spalte].Paragraphs[0]
                .Append(RegisterLayout.Spaltenkoepfe[spalte], RegisterLayout.Zellenschrift(fett: true));
        }
        RegisterLayout.AlsWiederholtenKopfMarkieren(zeile);
    }

    /// <summary>
    /// Die Jahresüberschrift als eigene Zeile über die volle Breite — in der
    /// Vorlagendatei steht sie in Spalte 1 und fehlt ab 2025 ganz.
    ///
    /// Sie bekommt zusätzlich eine Überschriften-Formatvorlage. Das ist nicht
    /// Kosmetik: Daraus entstehen beim PDF-Export die Sprungmarken, mit denen
    /// man auf dem Handy direkt auf einen Jahrgang springt, statt durch
    /// Dutzende Seiten zu wischen.
    /// </summary>
    static void Jahreszeile(Row zeile, string jahr)
    {
        zeile.MergeCells(0, RegisterLayout.Spaltenkoepfe.Length - 1);
        var absatz = zeile.Cells[0].Paragraphs[0]
            .Append(jahr, RegisterLayout.Zellenschrift(fett: true));
        absatz.StyleId = "Heading2";
    }

    static void Datenzeile(Row zeile, RegisterZeile daten)
    {
        var schrift = RegisterLayout.Zellenschrift(kursiv: !daten.Abgeschlossen);
        var nummer = daten.LaufendeNummer?.ToString("00", CultureInfo.InvariantCulture) ?? "—";

        zeile.Cells[0].Paragraphs[0].Append(nummer, schrift);
        zeile.Cells[1].Paragraphs[0].Append(daten.Zeichen, schrift);
        zeile.Cells[3].Paragraphs[0].Append(daten.Rechtsgebiet, schrift);

        // Parteien und Sachbestand stehen in derselben Spalte, aber in zwei
        // Absätzen: In der Vorlagendatei sind sie mit Leerzeichen aneinander-
        // geschoben, und genau daran scheitert jeder Versuch, sie später wieder
        // auseinanderzunehmen.
        var spalte = zeile.Cells[2];
        spalte.Paragraphs[0].Append(daten.Parteien, schrift);
        if (daten.Sachbestand.Length > 0)
            spalte.InsertParagraph().Append(daten.Sachbestand, schrift);
    }
}
