using System.Text.RegularExpressions;
using Xceed.Document.NET;
using Xceed.Words.NET;

/// <summary>
/// Modus <c>vollmacht</c> (§4.11): macht aus den drei Vollmacht-Vorlagen der Kanzlei
/// (<c>Beispiele/Vollmacht Vorlagen/</c>) die parametrisierten Dateien unter den festen
/// Namen im Unterordner <c>Vollmacht/</c> des Vorlagenordners.
///
/// Ein eigener Modus, weil der Standardlauf die Anspruchsschreiben neu schreibt — und
/// die liegen im Vorlagenordner der Kanzlei womöglich schon in einer nachbearbeiteten
/// Fassung. Wer nur die Vollmachten braucht, soll sie nicht mitverlieren.
///
/// Zwei Arten von Eingriffen:
/// <list type="bullet">
/// <item>Ersetzungen aus <c>vollmacht.local.tsv</c> — die Mandantendaten der
/// Ausgangsdateien. Echte Personendaten, deshalb nicht hier und per .gitignore
/// (<c>*.local.tsv</c>) ausgeschlossen.</item>
/// <item>Einfügungen hinter festen Beschriftungen („in Sachen:", „Tel.-Nr. des
/// Mandanten:", „E-Mail Mandant:"), wo die Ausgangsdatei leer ist. Sie tragen keine
/// Personendaten und stehen deshalb hier.</item>
/// </list>
///
/// Überschreibt nie: Eine Datei unter dem festen Namen hat der Anwalt womöglich schon
/// angepasst. Wer neu erzeugen will, löscht sie vorher.
/// </summary>
static class VollmachtParametrisierung
{
    static readonly (string Quelle, string Ziel)[] Dateien =
    [
        ("VOLLMACHT in UNFALLSACHEN.docx", "Vollmacht Unfallsachen.docx"),
        ("VOLLMACHT in BUSSGELDSACHEN.docx", "Vollmacht Bussgeldsachen.docx"),
        ("VOLLMACHT Strafsache.docx", "Vollmacht Strafsache.docx"),
    ];

    /// <summary>Beschriftung, hinter der ein Platzhalter eingefügt wird, sofern dort noch nichts steht.</summary>
    static readonly (string Beschriftung, string Platzhalter)[] Einfuegungen =
    [
        ("in Sachen:", "{{InSachen}}"),
        ("des Mandanten:", " {{MandantTelefon}}"),
        ("E-Mail Mandant:", " {{MandantEmail}}"),
    ];

    public static int Lauf(string root, string vorlagenOrdner, string tabellenPfad)
    {
        if (!File.Exists(tabellenPfad))
        {
            Console.Error.WriteLine($"""
                Ersetzungstabelle nicht gefunden: {Path.GetFullPath(tabellenPfad)}

                Eine Zeile je Ersetzung, Suchtext und Platzhalter durch einen Tabulator
                getrennt — die Mandantendaten der drei Ausgangsdateien (Name und
                Anschrift, „in Sachen", „wegen"). Aufbau wie ersetzungen.example.tsv.
                """);
            return 1;
        }

        var tabelle = File.ReadAllLines(tabellenPfad)
            .Select(zeile => zeile.TrimEnd('\r'))
            .Where(zeile => zeile.Length > 0 && !zeile.StartsWith('#'))
            .Select(zeile => zeile.Split('\t', 2))
            .Where(teile => teile.Length == 2)
            .Select(teile => (Search: teile[0], Replace: teile[1]))
            .ToArray();

        var zielOrdner = Path.Combine(vorlagenOrdner, "Vollmacht");
        Directory.CreateDirectory(zielOrdner);
        var fehler = 0;

        foreach (var (quelle, ziel) in Dateien)
        {
            var quellPfad = Path.Combine(root, "Beispiele", "Vollmacht Vorlagen", quelle);
            var zielPfad = Path.Combine(zielOrdner, ziel);
            if (File.Exists(zielPfad))
            {
                Console.WriteLine($"Übersprungen, liegt schon da: {zielPfad}");
                continue;
            }

            fehler += Parametrisiere(quellPfad, zielPfad, tabelle);
        }

        return fehler == 0 ? 0 : 1;
    }

    static int Parametrisiere(string quellPfad, string zielPfad, (string Search, string Replace)[] tabelle)
    {
        using var dokument = DocX.Load(quellPfad);
        foreach (var (search, replace) in tabelle)
        {
            dokument.ReplaceText(new StringReplaceTextOptions { SearchValue = search, NewValue = replace });
        }

        foreach (var absatz in dokument.Paragraphs)
        {
            foreach (var (beschriftung, platzhalter) in Einfuegungen)
            {
                var stelle = absatz.Text.IndexOf(beschriftung, StringComparison.Ordinal);
                if (stelle < 0)
                {
                    continue;
                }

                // Nur, wo hinter der Beschriftung noch kein Platzhalter steht — in der
                // Bußgeldvollmacht ersetzt die Tabelle „in Sachen" bereits.
                var ende = stelle + beschriftung.Length;
                var rest = absatz.Text[ende..];
                if (rest.TrimStart().StartsWith("{{", StringComparison.Ordinal))
                {
                    continue;
                }

                // Hinter „in Sachen:" folgt ein Tabulator zur Wertspalte; der Wert gehört dahinter.
                var ziel = beschriftung == "in Sachen:" && rest.Trim().Length == 0 ? absatz.Text.Length : ende;
                absatz.InsertText(ziel, platzhalter);
            }
        }

        dokument.SaveAs(zielPfad);

        using var ergebnis = DocX.Load(zielPfad);
        var offen = Regex.Matches(ergebnis.Text, @"\{\{(.*?)\}\}|\{\{[^}]*\]\]")
            .Select(treffer => treffer.Value)
            .Where(wert => !BekanntePlatzhalter.Contains(wert))
            .Distinct()
            .ToList();
        Console.WriteLine($"Erstellt: {zielPfad}");
        if (offen.Count == 0)
        {
            return 0;
        }

        Console.Error.WriteLine($"  Unbekannte Platzhalter-Reste: {string.Join(", ", offen)}");
        return 1;
    }

    /// <summary>Was der Dienst einsetzt (<c>VollmachtAuftrag.Platzhalter</c>).</summary>
    static readonly HashSet<string> BekanntePlatzhalter =
    [
        "{{MandantVorname}}", "{{MandantNachname}}", "{{MandantName}}", "{{MandantStrasse}}",
        "{{MandantPlz}}", "{{MandantOrt}}", "{{MandantAnschrift}}", "{{MandantTelefon}}",
        "{{MandantEmail}}", "{{Unfalldatum}}", "{{InSachen}}", "{{Wegen}}",
    ];
}
